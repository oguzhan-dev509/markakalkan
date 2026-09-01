from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

from markakalkan_release.execution_shell import (
    AuthorizationError,
    ReleaseExecutionPlan,
)
from markakalkan_release.local_mutation_executor import (
    LocalMutationExecutor,
    LocalMutationPlanError,
    LocalSimulationOnlyError,
)
from markakalkan_release.n8n_client import N8nOperation
from markakalkan_release.safety import SingleUseLockExists


class FakeSimulationClient:
    simulation_only = True

    def __init__(self):
        self.calls = []

    def get_workflow(self, workflow_id):
        self.calls.append(("GET", workflow_id))
        return {
            "id": workflow_id,
            "versionId": "v1",
            "activeVersionId": "v1",
            "staticData": None,
        }

    def save_draft(self, workflow_id, payload):
        self.calls.append(("PUT", workflow_id, dict(payload)))
        return {
            "id": workflow_id,
            "versionId": "v2",
            "activeVersionId": "v1",
            "staticData": None,
        }

    def publish_exact_version(self, workflow_id, version_id):
        self.calls.append(("POST", workflow_id, version_id))
        return {
            "id": workflow_id,
            "versionId": version_id,
            "activeVersionId": version_id,
            "staticData": None,
        }


class UnsafeClient(FakeSimulationClient):
    simulation_only = False


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


class LocalMutationExecutorTests(unittest.TestCase):
    def lock_path(self, td):
        return Path(td) / "locks" / "phase4.lock.json"

    def test_exact_authorized_sequence_runs_in_order_and_writes_lock(self):
        plan = full_plan()
        client = FakeSimulationClient()

        with tempfile.TemporaryDirectory() as td:
            lock = self.lock_path(td)
            final, receipt = LocalMutationExecutor().execute(
                plan=plan,
                typed_authorization=plan.authorization_text(),
                client=client,
                single_use_lock_path=lock,
                draft_payload={"name": "target"},
            )

            self.assertTrue(lock.is_file())
            record = json.loads(lock.read_text(encoding="utf-8"))
            self.assertEqual(record["stage"], "LOCAL_MUTATION_SIMULATION")
            self.assertEqual(record["workflowId"], "abc")
            self.assertEqual(record["planSha256"], plan.fingerprint_sha256())
            self.assertEqual(record["rerunAllowed"], False)
            self.assertEqual(receipt.single_use_lock_path, str(lock))

        self.assertEqual(
            [c[0] for c in client.calls],
            ["GET", "PUT", "GET", "POST", "GET"],
        )
        self.assertEqual(final["activeVersionId"], "v1")
        self.assertEqual(receipt.operation_count, 5)
        self.assertEqual(receipt.mutation_operation_count, 2)

    def test_second_attempt_same_lock_blocks_before_any_client_call(self):
        plan = full_plan()

        with tempfile.TemporaryDirectory() as td:
            lock = self.lock_path(td)
            first = FakeSimulationClient()
            LocalMutationExecutor().execute(
                plan=plan,
                typed_authorization=plan.authorization_text(),
                client=first,
                single_use_lock_path=lock,
                draft_payload={"name": "target"},
            )
            second = FakeSimulationClient()
            with self.assertRaises(SingleUseLockExists):
                LocalMutationExecutor().execute(
                    plan=plan,
                    typed_authorization=plan.authorization_text(),
                    client=second,
                    single_use_lock_path=lock,
                    draft_payload={"name": "target"},
                )

            self.assertEqual(second.calls, [])

    def test_wrong_authorization_creates_no_lock_and_no_calls(self):
        plan = full_plan()
        client = FakeSimulationClient()

        with tempfile.TemporaryDirectory() as td:
            lock = self.lock_path(td)
            with self.assertRaises(AuthorizationError):
                LocalMutationExecutor().execute(
                    plan=plan,
                    typed_authorization="WRONG",
                    client=client,
                    single_use_lock_path=lock,
                    draft_payload={"name": "target"},
                )
            self.assertFalse(lock.exists())

        self.assertEqual(client.calls, [])

    def test_non_simulation_client_creates_no_lock_and_no_calls(self):
        plan = full_plan()
        client = UnsafeClient()

        with tempfile.TemporaryDirectory() as td:
            lock = self.lock_path(td)
            with self.assertRaises(LocalSimulationOnlyError):
                LocalMutationExecutor().execute(
                    plan=plan,
                    typed_authorization=plan.authorization_text(),
                    client=client,
                    single_use_lock_path=lock,
                    draft_payload={"name": "target"},
                )
            self.assertFalse(lock.exists())

        self.assertEqual(client.calls, [])

    def test_missing_payload_consumes_lock_before_first_client_call_then_fails_after_read(self):
        plan = ReleaseExecutionPlan(
            workflow_id="abc",
            operations=(
                N8nOperation.READ_WORKFLOW,
                N8nOperation.SAVE_DRAFT,
            ),
            update_budget=1,
            publish_budget=0,
        )
        client = FakeSimulationClient()

        with tempfile.TemporaryDirectory() as td:
            lock = self.lock_path(td)
            with self.assertRaises(LocalMutationPlanError):
                LocalMutationExecutor().execute(
                    plan=plan,
                    typed_authorization=plan.authorization_text(),
                    client=client,
                    single_use_lock_path=lock,
                )
            self.assertTrue(lock.is_file())

        self.assertEqual([c[0] for c in client.calls], ["GET"])

    def test_lock_path_must_be_path_and_no_client_call_occurs(self):
        plan = full_plan()
        client = FakeSimulationClient()

        with self.assertRaises(TypeError):
            LocalMutationExecutor().execute(
                plan=plan,
                typed_authorization=plan.authorization_text(),
                client=client,
                single_use_lock_path="not-a-path",
                draft_payload={"name": "target"},
            )

        self.assertEqual(client.calls, [])

    def test_release_plan_rejects_second_save_over_budget(self):
        with self.assertRaises(ValueError):
            ReleaseExecutionPlan(
                workflow_id="abc",
                operations=(
                    N8nOperation.SAVE_DRAFT,
                    N8nOperation.SAVE_DRAFT,
                ),
                update_budget=1,
                publish_budget=0,
            )

    def test_release_plan_rejects_second_publish_over_budget(self):
        with self.assertRaises(ValueError):
            ReleaseExecutionPlan(
                workflow_id="abc",
                operations=(
                    N8nOperation.PUBLISH_EXACT_VERSION,
                    N8nOperation.PUBLISH_EXACT_VERSION,
                ),
                update_budget=0,
                publish_budget=1,
                exact_version_id="v2",
            )


if __name__ == "__main__":
    unittest.main()
