from __future__ import annotations
import json
from pathlib import Path
import tempfile
import unittest
from markakalkan_release.n8n_client import N8nWorkflowClient, ResponseContractError, ScopeError
from markakalkan_release.safety import MutationBudget, MutationBudgetExceeded, MutationKind, SingleUseLockExists, acquire_single_use_lock

class FakeTransport:
    def __init__(self, response=None):
        self.calls = []
        self.response = {"ok": True} if response is None else response
    def request(self, method, path, body=None):
        self.calls.append((method, path, body))
        return self.response

def budget(update=0, publish=0):
    return MutationBudget({MutationKind.UPDATE_DRAFT: update, MutationKind.PUBLISH: publish})

class ClientTests(unittest.TestCase):
    def test_read_scope_and_exact_path(self):
        t = FakeTransport({"id": "abc"})
        c = N8nWorkflowClient(transport=t, declared_scopes=["workflow:read"], mutation_budget=budget())
        self.assertEqual(c.get_workflow("abc")["id"], "abc")
        self.assertEqual(t.calls, [("GET", "/api/v1/workflows/abc", None)])

    def test_read_scope_missing_fails_closed(self):
        c = N8nWorkflowClient(transport=FakeTransport(), declared_scopes=[], mutation_budget=budget())
        with self.assertRaises(ScopeError): c.get_workflow("abc")

    def test_save_draft_exact_contract(self):
        t = FakeTransport()
        c = N8nWorkflowClient(transport=t, declared_scopes=["workflow:update"], mutation_budget=budget(update=1))
        c.save_draft("abc", {"name": "x"})
        self.assertEqual(t.calls, [("PUT", "/api/v1/workflows/abc?publishIfActive=false", {"name": "x"})])

    def test_second_update_fails_before_transport(self):
        t = FakeTransport()
        c = N8nWorkflowClient(transport=t, declared_scopes=["workflow:update"], mutation_budget=budget(update=1))
        c.save_draft("abc", {"name": "x"})
        with self.assertRaises(MutationBudgetExceeded): c.save_draft("abc", {"name": "y"})
        self.assertEqual(len(t.calls), 1)

    def test_publish_exact_contract(self):
        t = FakeTransport()
        c = N8nWorkflowClient(transport=t, declared_scopes=["workflow:activate"], mutation_budget=budget(publish=1))
        c.publish_exact_version("abc", "v1")
        self.assertEqual(t.calls, [("POST", "/api/v1/workflows/abc/publish", {"versionId": "v1"})])

    def test_publish_scope_missing_fails_closed(self):
        c = N8nWorkflowClient(transport=FakeTransport(), declared_scopes=["workflow:read"], mutation_budget=budget(publish=1))
        with self.assertRaises(ScopeError): c.publish_exact_version("abc", "v1")

    def test_bad_ids_fail_before_transport_or_budget(self):
        t = FakeTransport()
        b = budget(publish=1)
        c = N8nWorkflowClient(transport=t, declared_scopes=["workflow:activate"], mutation_budget=b)
        with self.assertRaises(ValueError): c.publish_exact_version("abc", "bad/version")
        self.assertEqual(t.calls, [])
        self.assertEqual(b.used(MutationKind.PUBLISH), 0)

    def test_non_object_response_fails_closed(self):
        c = N8nWorkflowClient(transport=FakeTransport([]), declared_scopes=["workflow:read"], mutation_budget=budget())
        with self.assertRaises(ResponseContractError): c.get_workflow("abc")

class BudgetTests(unittest.TestCase):
    def test_missing_limit_defaults_zero(self):
        with self.assertRaises(MutationBudgetExceeded): MutationBudget({}).consume(MutationKind.PUBLISH)

    def test_negative_and_boolean_limits_rejected(self):
        with self.assertRaises(ValueError): MutationBudget({MutationKind.PUBLISH: -1})
        with self.assertRaises(ValueError): MutationBudget({MutationKind.PUBLISH: True})

    def test_snapshot(self):
        b = budget(update=1, publish=2)
        b.consume(MutationKind.PUBLISH)
        self.assertEqual(b.snapshot()["PUBLISH"], {"limit": 2, "used": 1, "remaining": 1})

class LockTests(unittest.TestCase):
    def test_lock_forces_rerun_false(self):
        with tempfile.TemporaryDirectory() as tmp:
            p = Path(tmp) / "lock.json"
            acquire_single_use_lock(p, {"stage": "X", "rerunAllowed": True})
            self.assertIs(json.loads(p.read_text(encoding="utf-8"))["rerunAllowed"], False)

    def test_existing_lock_not_overwritten(self):
        with tempfile.TemporaryDirectory() as tmp:
            p = Path(tmp) / "lock.json"
            acquire_single_use_lock(p, {"stage": "FIRST"})
            before = p.read_bytes()
            with self.assertRaises(SingleUseLockExists): acquire_single_use_lock(p, {"stage": "SECOND"})
            self.assertEqual(p.read_bytes(), before)

if __name__ == "__main__":
    unittest.main()
