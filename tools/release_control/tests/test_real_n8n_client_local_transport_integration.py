from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from markakalkan_release.execution_shell import ReleaseExecutionPlan
from markakalkan_release.local_mutation_executor import LocalMutationExecutor
from markakalkan_release.n8n_client import N8nOperation, N8nWorkflowClient
from markakalkan_release.safety import MutationBudget, MutationKind, SingleUseLockExists


class ScriptedTransport:
    """In-memory request/response script. No sockets and no HTTP imports."""

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


class SimulationN8nClientAdapter:
    simulation_only = True

    def __init__(self, inner):
        self.inner = inner

    def get_workflow(self, workflow_id):
        return self.inner.get_workflow(workflow_id)

    def save_draft(self, workflow_id, payload):
        return self.inner.save_draft(workflow_id, payload)

    def publish_exact_version(self, workflow_id, version_id):
        return self.inner.publish_exact_version(workflow_id, version_id)


def execution_plan():
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


def workflow(version_id, active_version_id):
    return {
        "id": "abc",
        "name": "simulation",
        "versionId": version_id,
        "activeVersionId": active_version_id,
        "staticData": None,
    }


class RealN8nClientLocalTransportIntegrationTests(unittest.TestCase):
    def make_stack(self):
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
        real_client = N8nWorkflowClient(
            transport=transport,
            declared_scopes=[
                "workflow:read",
                "workflow:update",
                "workflow:activate",
            ],
            mutation_budget=budget,
        )
        return (
            transport,
            budget,
            SimulationN8nClientAdapter(real_client),
        )

    def test_real_client_exact_get_put_get_post_get_sequence(self):
        plan = execution_plan()
        transport, budget, client = self.make_stack()

        with tempfile.TemporaryDirectory() as td:
            lock = Path(td) / "phase4d.lock.json"
            final, receipt = LocalMutationExecutor().execute(
                plan=plan,
                typed_authorization=plan.authorization_text(),
                client=client,
                single_use_lock_path=lock,
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
        self.assertEqual(receipt.operation_count, 5)
        self.assertEqual(receipt.mutation_operation_count, 2)
        self.assertEqual(budget.used(MutationKind.UPDATE_DRAFT), 1)
        self.assertEqual(budget.used(MutationKind.PUBLISH), 1)
        self.assertEqual(budget.remaining(MutationKind.UPDATE_DRAFT), 0)
        self.assertEqual(budget.remaining(MutationKind.PUBLISH), 0)

    def test_second_attempt_same_lock_stops_before_real_client_transport(self):
        plan = execution_plan()
        first_transport, _, first_client = self.make_stack()

        with tempfile.TemporaryDirectory() as td:
            lock = Path(td) / "phase4d.lock.json"
            LocalMutationExecutor().execute(
                plan=plan,
                typed_authorization=plan.authorization_text(),
                client=first_client,
                single_use_lock_path=lock,
                draft_payload={"name": "target", "staticData": None},
            )
            first_transport.assert_exhausted()

            second_transport, second_budget, second_client = self.make_stack()
            with self.assertRaises(SingleUseLockExists):
                LocalMutationExecutor().execute(
                    plan=plan,
                    typed_authorization=plan.authorization_text(),
                    client=second_client,
                    single_use_lock_path=lock,
                    draft_payload={"name": "target", "staticData": None},
                )

            self.assertEqual(second_transport.calls, [])
            self.assertEqual(second_budget.used(MutationKind.UPDATE_DRAFT), 0)
            self.assertEqual(second_budget.used(MutationKind.PUBLISH), 0)

    def test_missing_update_scope_fails_before_put_and_budget_not_consumed(self):
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
        real_client = N8nWorkflowClient(
            transport=transport,
            declared_scopes=[
                "workflow:read",
                "workflow:activate",
            ],
            mutation_budget=budget,
        )
        client = SimulationN8nClientAdapter(real_client)
        plan = execution_plan()

        with tempfile.TemporaryDirectory() as td:
            lock = Path(td) / "phase4d.lock.json"
            with self.assertRaises(PermissionError):
                LocalMutationExecutor().execute(
                    plan=plan,
                    typed_authorization=plan.authorization_text(),
                    client=client,
                    single_use_lock_path=lock,
                    draft_payload={"name": "target", "staticData": None},
                )
            self.assertTrue(lock.is_file())

        transport.assert_exhausted()
        self.assertEqual(
            [call[0] for call in transport.calls],
            ["GET"],
        )
        self.assertEqual(budget.used(MutationKind.UPDATE_DRAFT), 0)
        self.assertEqual(budget.used(MutationKind.PUBLISH), 0)

    def test_client_second_publish_budget_blocks_before_transport(self):
        transport = ScriptedTransport(
            [
                (
                    "POST",
                    "/api/v1/workflows/abc/publish",
                    {"versionId": "v2"},
                    workflow("v2", "v2"),
                ),
            ]
        )
        budget = MutationBudget(
            {
                MutationKind.UPDATE_DRAFT: 0,
                MutationKind.PUBLISH: 1,
            }
        )
        client = N8nWorkflowClient(
            transport=transport,
            declared_scopes=["workflow:activate"],
            mutation_budget=budget,
        )

        client.publish_exact_version("abc", "v2")
        transport.assert_exhausted()

        with self.assertRaises(Exception):
            client.publish_exact_version("abc", "v2")

        self.assertEqual(len(transport.calls), 1)
        self.assertEqual(budget.used(MutationKind.PUBLISH), 1)


if __name__ == "__main__":
    unittest.main()
