from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from markakalkan_release.execution_shell import (
    LiveExecutionDisabled,
    LiveMutationPermit,
    ReleaseExecutionPlan,
    ReleaseExecutionShell,
)
from markakalkan_release.n8n_client import N8nOperation, N8nWorkflowClient
from markakalkan_release.safety import (
    MutationBudget,
    MutationKind,
    SingleUseLockExists,
)


class ScriptedTransport:
    """Pure in-memory transport: no socket, urllib, HTTP, or n8n."""

    def __init__(self, script):
        self.script = list(script)
        self.calls = []

    def request(self, method, path, body=None):
        self.calls.append((method, path, body))
        if not self.script:
            raise AssertionError("unexpected extra transport call")

        expected_method, expected_path, expected_body, response = self.script.pop(0)
        if method != expected_method:
            raise AssertionError(
                f"method mismatch: expected {expected_method}, got {method}"
            )
        if path != expected_path:
            raise AssertionError(
                f"path mismatch: expected {expected_path}, got {path}"
            )
        if body != expected_body:
            raise AssertionError(
                f"body mismatch: expected {expected_body!r}, got {body!r}"
            )
        return response

    def assert_exhausted(self):
        if self.script:
            raise AssertionError(
                f"unconsumed scripted calls: {len(self.script)}"
            )


def workflow(version_id, active_version_id):
    return {
        "id": "abc",
        "name": "phase5-live-shell-simulation",
        "versionId": version_id,
        "activeVersionId": active_version_id,
        "staticData": None,
    }


def full_plan():
    return ReleaseExecutionPlan(
        workflow_id="abc",
        operations=(
            N8nOperation.READ_WORKFLOW,
            N8nOperation.SAVE_DRAFT,
            N8nOperation.READ_WORKFLOW,
            N8nOperation.PUBLISH_EXACT_VERSION,
            N8nOperation.READ_WORKFLOW,
        ),
        update_budget=1,
        publish_budget=1,
        exact_version_id="v2",
    )


def scripted_stack(scopes=None):
    transport = ScriptedTransport(
        [
            (
                "GET",
                "/api/v1/workflows/abc",
                None,
                workflow("v1", "v1"),
            ),
            (
                "PUT",
                "/api/v1/workflows/abc?publishIfActive=false",
                {"name": "target", "staticData": None},
                workflow("v2", "v1"),
            ),
            (
                "GET",
                "/api/v1/workflows/abc",
                None,
                workflow("v2", "v1"),
            ),
            (
                "POST",
                "/api/v1/workflows/abc/publish",
                {"versionId": "v2"},
                workflow("v2", "v2"),
            ),
            (
                "GET",
                "/api/v1/workflows/abc",
                None,
                workflow("v2", "v2"),
            ),
        ]
    )
    budget = MutationBudget(
        {
            MutationKind.UPDATE_DRAFT: 1,
            MutationKind.PUBLISH: 1,
        }
    )
    client = N8nWorkflowClient(
        transport=transport,
        declared_scopes=scopes or [
            "workflow:read",
            "workflow:update",
            "workflow:activate",
        ],
        mutation_budget=budget,
    )
    return transport, budget, client


class LiveMutationShellRealClientScriptedTransportTests(unittest.TestCase):
    def test_enabled_live_shell_real_client_exact_sequence_and_budget(self):
        plan = full_plan()
        transport, budget, client = scripted_stack()

        with tempfile.TemporaryDirectory() as td:
            lock = Path(td) / "phase5c.lock.json"
            permit = LiveMutationPermit(
                plan_sha256=plan.fingerprint_sha256(),
                single_use_lock_path=lock,
            )
            final, receipt = ReleaseExecutionShell(
                live_mutation_enabled=True
            ).execute_live_mutation(
                plan=plan,
                typed_authorization=plan.authorization_text(),
                client=client,
                permit=permit,
                draft_payload={"name": "target", "staticData": None},
            )
            self.assertTrue(lock.is_file())

        transport.assert_exhausted()
        self.assertEqual(
            [call[0] for call in transport.calls],
            ["GET", "PUT", "GET", "POST", "GET"],
        )
        self.assertEqual(final["versionId"], "v2")
        self.assertEqual(final["activeVersionId"], "v2")
        self.assertEqual(receipt.update_count, 1)
        self.assertEqual(receipt.publish_count, 1)
        self.assertEqual(budget.used(MutationKind.UPDATE_DRAFT), 1)
        self.assertEqual(budget.used(MutationKind.PUBLISH), 1)
        self.assertEqual(budget.remaining(MutationKind.UPDATE_DRAFT), 0)
        self.assertEqual(budget.remaining(MutationKind.PUBLISH), 0)

    def test_default_disabled_real_client_zero_transport_zero_budget(self):
        plan = full_plan()
        transport, budget, client = scripted_stack()

        with tempfile.TemporaryDirectory() as td:
            lock = Path(td) / "phase5c.lock.json"
            permit = LiveMutationPermit(
                plan_sha256=plan.fingerprint_sha256(),
                single_use_lock_path=lock,
            )
            with self.assertRaises(LiveExecutionDisabled):
                ReleaseExecutionShell().execute_live_mutation(
                    plan=plan,
                    typed_authorization=plan.authorization_text(),
                    client=client,
                    permit=permit,
                    draft_payload={"name": "target", "staticData": None},
                )
            self.assertFalse(lock.exists())

        self.assertEqual(transport.calls, [])
        self.assertEqual(budget.used(MutationKind.UPDATE_DRAFT), 0)
        self.assertEqual(budget.used(MutationKind.PUBLISH), 0)

    def test_missing_update_scope_consumes_lock_then_stops_before_put(self):
        plan = full_plan()
        transport = ScriptedTransport(
            [
                (
                    "GET",
                    "/api/v1/workflows/abc",
                    None,
                    workflow("v1", "v1"),
                ),
            ]
        )
        budget = MutationBudget(
            {
                MutationKind.UPDATE_DRAFT: 1,
                MutationKind.PUBLISH: 1,
            }
        )
        client = N8nWorkflowClient(
            transport=transport,
            declared_scopes=[
                "workflow:read",
                "workflow:activate",
            ],
            mutation_budget=budget,
        )

        with tempfile.TemporaryDirectory() as td:
            lock = Path(td) / "phase5c.lock.json"
            permit = LiveMutationPermit(
                plan_sha256=plan.fingerprint_sha256(),
                single_use_lock_path=lock,
            )
            with self.assertRaises(PermissionError):
                ReleaseExecutionShell(
                    live_mutation_enabled=True
                ).execute_live_mutation(
                    plan=plan,
                    typed_authorization=plan.authorization_text(),
                    client=client,
                    permit=permit,
                    draft_payload={"name": "target", "staticData": None},
                )
            self.assertTrue(lock.is_file())

        transport.assert_exhausted()
        self.assertEqual([c[0] for c in transport.calls], ["GET"])
        self.assertEqual(budget.used(MutationKind.UPDATE_DRAFT), 0)
        self.assertEqual(budget.used(MutationKind.PUBLISH), 0)

    def test_second_attempt_same_lock_real_client_zero_transport(self):
        plan = full_plan()

        with tempfile.TemporaryDirectory() as td:
            lock = Path(td) / "phase5c.lock.json"
            permit = LiveMutationPermit(
                plan_sha256=plan.fingerprint_sha256(),
                single_use_lock_path=lock,
            )

            first_transport, _, first_client = scripted_stack()
            shell = ReleaseExecutionShell(live_mutation_enabled=True)
            shell.execute_live_mutation(
                plan=plan,
                typed_authorization=plan.authorization_text(),
                client=first_client,
                permit=permit,
                draft_payload={"name": "target", "staticData": None},
            )
            first_transport.assert_exhausted()

            second_transport, second_budget, second_client = scripted_stack()
            with self.assertRaises(SingleUseLockExists):
                shell.execute_live_mutation(
                    plan=plan,
                    typed_authorization=plan.authorization_text(),
                    client=second_client,
                    permit=permit,
                    draft_payload={"name": "target", "staticData": None},
                )

            self.assertEqual(second_transport.calls, [])
            self.assertEqual(
                second_budget.used(MutationKind.UPDATE_DRAFT), 0
            )
            self.assertEqual(
                second_budget.used(MutationKind.PUBLISH), 0
            )


if __name__ == "__main__":
    unittest.main()
