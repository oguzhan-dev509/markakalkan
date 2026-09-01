from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from markakalkan_release.execution_shell import (
    AuthorizationError,
    LiveExecutionDisabled,
    LiveMutationPermit,
    LiveMutationPlanError,
    ReleaseExecutionPlan,
    ReleaseExecutionShell,
)
from markakalkan_release.n8n_client import N8nOperation
from markakalkan_release.safety import SingleUseLockExists


class FakeMutationClient:
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


class LiveMutationShellTests(unittest.TestCase):
    def test_default_disabled_blocks_before_lock_and_client(self):
        plan = full_plan()
        client = FakeMutationClient()

        with tempfile.TemporaryDirectory() as td:
            lock = Path(td) / "live.lock.json"
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

        self.assertEqual(client.calls, [])

    def test_enabled_exact_execution_writes_lock_and_runs_ordered_sequence(self):
        plan = full_plan()
        client = FakeMutationClient()

        with tempfile.TemporaryDirectory() as td:
            lock = Path(td) / "live.lock.json"
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
            self.assertEqual(receipt.single_use_lock_path, str(lock))

        self.assertEqual(
            [call[0] for call in client.calls],
            ["GET", "PUT", "GET", "POST", "GET"],
        )
        self.assertEqual(final["activeVersionId"], "v1")
        self.assertEqual(receipt.update_count, 1)
        self.assertEqual(receipt.publish_count, 1)

    def test_wrong_authorization_blocks_before_lock_and_client(self):
        plan = full_plan()
        client = FakeMutationClient()

        with tempfile.TemporaryDirectory() as td:
            lock = Path(td) / "live.lock.json"
            permit = LiveMutationPermit(
                plan_sha256=plan.fingerprint_sha256(),
                single_use_lock_path=lock,
            )
            with self.assertRaises(AuthorizationError):
                ReleaseExecutionShell(
                    live_mutation_enabled=True
                ).execute_live_mutation(
                    plan=plan,
                    typed_authorization="WRONG",
                    client=client,
                    permit=permit,
                    draft_payload={"name": "target", "staticData": None},
                )
            self.assertFalse(lock.exists())

        self.assertEqual(client.calls, [])

    def test_permit_fingerprint_mismatch_blocks_before_lock_and_client(self):
        plan = full_plan()
        client = FakeMutationClient()

        with tempfile.TemporaryDirectory() as td:
            lock = Path(td) / "live.lock.json"
            permit = LiveMutationPermit(
                plan_sha256="0" * 64,
                single_use_lock_path=lock,
            )
            with self.assertRaises(AuthorizationError):
                ReleaseExecutionShell(
                    live_mutation_enabled=True
                ).execute_live_mutation(
                    plan=plan,
                    typed_authorization=plan.authorization_text(),
                    client=client,
                    permit=permit,
                    draft_payload={"name": "target", "staticData": None},
                )
            self.assertFalse(lock.exists())

        self.assertEqual(client.calls, [])

    def test_second_attempt_same_lock_blocks_before_client(self):
        plan = full_plan()

        with tempfile.TemporaryDirectory() as td:
            lock = Path(td) / "live.lock.json"
            permit = LiveMutationPermit(
                plan_sha256=plan.fingerprint_sha256(),
                single_use_lock_path=lock,
            )
            shell = ReleaseExecutionShell(live_mutation_enabled=True)
            first = FakeMutationClient()
            shell.execute_live_mutation(
                plan=plan,
                typed_authorization=plan.authorization_text(),
                client=first,
                permit=permit,
                draft_payload={"name": "target", "staticData": None},
            )

            second = FakeMutationClient()
            with self.assertRaises(SingleUseLockExists):
                shell.execute_live_mutation(
                    plan=plan,
                    typed_authorization=plan.authorization_text(),
                    client=second,
                    permit=permit,
                    draft_payload={"name": "target", "staticData": None},
                )
            self.assertEqual(second.calls, [])

    def test_read_only_plan_is_rejected_before_lock_and_client(self):
        plan = ReleaseExecutionPlan(
            workflow_id="abc",
            operations=(N8nOperation.READ_WORKFLOW,),
            update_budget=0,
            publish_budget=0,
        )
        client = FakeMutationClient()

        with tempfile.TemporaryDirectory() as td:
            lock = Path(td) / "live.lock.json"
            permit = LiveMutationPermit(
                plan_sha256=plan.fingerprint_sha256(),
                single_use_lock_path=lock,
            )
            with self.assertRaises(LiveMutationPlanError):
                ReleaseExecutionShell(
                    live_mutation_enabled=True
                ).execute_live_mutation(
                    plan=plan,
                    typed_authorization=plan.authorization_text(),
                    client=client,
                    permit=permit,
                )
            self.assertFalse(lock.exists())

        self.assertEqual(client.calls, [])

    def test_shell_rejects_budget_above_one_before_lock_and_client(self):
        plan = ReleaseExecutionPlan(
            workflow_id="abc",
            operations=(N8nOperation.SAVE_DRAFT,),
            update_budget=2,
            publish_budget=0,
        )
        client = FakeMutationClient()

        with tempfile.TemporaryDirectory() as td:
            lock = Path(td) / "live.lock.json"
            permit = LiveMutationPermit(
                plan_sha256=plan.fingerprint_sha256(),
                single_use_lock_path=lock,
            )
            with self.assertRaises(LiveMutationPlanError):
                ReleaseExecutionShell(
                    live_mutation_enabled=True
                ).execute_live_mutation(
                    plan=plan,
                    typed_authorization=plan.authorization_text(),
                    client=client,
                    permit=permit,
                    draft_payload={"name": "target"},
                )
            self.assertFalse(lock.exists())

        self.assertEqual(client.calls, [])


if __name__ == "__main__":
    unittest.main()
