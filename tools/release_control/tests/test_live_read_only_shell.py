from __future__ import annotations

import unittest

from markakalkan_release.execution_shell import (
    AuthorizationError,
    LiveExecutionDisabled,
    ReadOnlyLivePlanError,
    ReleaseExecutionPlan,
    ReleaseExecutionShell,
)
from markakalkan_release.n8n_client import N8nOperation


class FakeReadClient:
    def __init__(self):
        self.calls = []

    def get_workflow(self, workflow_id):
        self.calls.append(workflow_id)
        return {
            "id": workflow_id,
            "name": "workflow",
            "active": True,
            "versionId": "v2",
            "activeVersionId": "v2",
            "staticData": None,
        }


def read_plan():
    return ReleaseExecutionPlan(
        workflow_id="abc",
        operations=(N8nOperation.READ_WORKFLOW,),
        update_budget=0,
        publish_budget=0,
    )


class LiveReadOnlyShellTests(unittest.TestCase):
    def test_exact_authorized_read_executes_once(self):
        plan = read_plan()
        client = FakeReadClient()
        workflow, receipt = ReleaseExecutionShell().execute_live_read_only(
            plan,
            plan.authorization_text(),
            client,
        )

        self.assertEqual(client.calls, ["abc"])
        self.assertEqual(workflow["id"], "abc")
        self.assertEqual(receipt.mode, "LIVE_READ_ONLY")
        self.assertEqual(receipt.network_call_count, 1)
        self.assertEqual(receipt.mutation_count, 0)
        self.assertEqual(receipt.plan_sha256, plan.fingerprint_sha256())

    def test_wrong_authorization_blocks_before_client(self):
        plan = read_plan()
        client = FakeReadClient()

        with self.assertRaises(AuthorizationError):
            ReleaseExecutionShell().execute_live_read_only(
                plan,
                "WRONG",
                client,
            )

        self.assertEqual(client.calls, [])

    def test_publish_plan_blocked_before_client(self):
        plan = ReleaseExecutionPlan(
            workflow_id="abc",
            operations=(N8nOperation.PUBLISH_EXACT_VERSION,),
            update_budget=0,
            publish_budget=1,
            exact_version_id="v2",
        )
        client = FakeReadClient()

        with self.assertRaises(ReadOnlyLivePlanError):
            ReleaseExecutionShell().execute_live_read_only(
                plan,
                plan.authorization_text(),
                client,
            )

        self.assertEqual(client.calls, [])

    def test_multiple_reads_blocked_before_client(self):
        plan = ReleaseExecutionPlan(
            workflow_id="abc",
            operations=(
                N8nOperation.READ_WORKFLOW,
                N8nOperation.READ_WORKFLOW,
            ),
            update_budget=0,
            publish_budget=0,
        )
        client = FakeReadClient()

        with self.assertRaises(ReadOnlyLivePlanError):
            ReleaseExecutionShell().execute_live_read_only(
                plan,
                plan.authorization_text(),
                client,
            )

        self.assertEqual(client.calls, [])

    def test_general_live_execution_still_disabled(self):
        plan = read_plan()
        with self.assertRaises(LiveExecutionDisabled):
            ReleaseExecutionShell().execute_live(
                plan,
                plan.authorization_text(),
            )


if __name__ == "__main__":
    unittest.main()
