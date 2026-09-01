from __future__ import annotations

import unittest

from markakalkan_release.execution_shell import (
    AuthorizationError,
    LiveExecutionDisabled,
    ReleaseExecutionPlan,
    ReleaseExecutionShell,
)
from markakalkan_release.n8n_client import N8nOperation


class PlanTests(unittest.TestCase):
    def test_read_only_plan_requires_only_read_scope(self):
        plan = ReleaseExecutionPlan(
            workflow_id="abc",
            operations=(N8nOperation.READ_WORKFLOW,),
            update_budget=0,
            publish_budget=0,
        )
        self.assertEqual(plan.required_scopes(), ("workflow:read",))

    def test_existing_draft_publish_plan_does_not_require_update_scope(self):
        plan = ReleaseExecutionPlan(
            workflow_id="abc",
            operations=(
                N8nOperation.READ_WORKFLOW,
                N8nOperation.PUBLISH_EXACT_VERSION,
                N8nOperation.READ_WORKFLOW,
            ),
            update_budget=0,
            publish_budget=1,
            exact_version_id="v2",
        )
        self.assertEqual(
            plan.required_scopes(),
            ("workflow:activate", "workflow:read"),
        )
        self.assertNotIn("workflow:update", plan.required_scopes())

    def test_new_draft_plan_requires_update_and_activate(self):
        plan = ReleaseExecutionPlan(
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
        self.assertEqual(
            plan.required_scopes(),
            ("workflow:activate", "workflow:read", "workflow:update"),
        )

    def test_publish_without_exact_version_fails_closed(self):
        with self.assertRaises(ValueError):
            ReleaseExecutionPlan(
                workflow_id="abc",
                operations=(N8nOperation.PUBLISH_EXACT_VERSION,),
                update_budget=0,
                publish_budget=1,
            )

    def test_operation_over_budget_fails_closed(self):
        with self.assertRaises(ValueError):
            ReleaseExecutionPlan(
                workflow_id="abc",
                operations=(N8nOperation.SAVE_DRAFT,),
                update_budget=0,
                publish_budget=0,
            )

    def test_exact_version_without_publish_fails_closed(self):
        with self.assertRaises(ValueError):
            ReleaseExecutionPlan(
                workflow_id="abc",
                operations=(N8nOperation.READ_WORKFLOW,),
                update_budget=0,
                publish_budget=0,
                exact_version_id="v2",
            )


class DryRunTests(unittest.TestCase):
    def test_dry_run_is_zero_network_zero_mutation(self):
        plan = ReleaseExecutionPlan(
            workflow_id="abc",
            operations=(
                N8nOperation.READ_WORKFLOW,
                N8nOperation.PUBLISH_EXACT_VERSION,
            ),
            update_budget=0,
            publish_budget=1,
            exact_version_id="v2",
        )
        receipt = ReleaseExecutionShell().dry_run(plan)
        self.assertEqual(receipt.network_call_count, 0)
        self.assertEqual(receipt.mutation_count, 0)
        self.assertEqual(receipt.plan_sha256, plan.fingerprint_sha256())
        self.assertEqual(
            receipt.authorization_required_for_live,
            plan.authorization_text(),
        )

    def test_plan_fingerprint_is_stable(self):
        left = ReleaseExecutionPlan(
            workflow_id="abc",
            operations=(N8nOperation.READ_WORKFLOW,),
            update_budget=0,
            publish_budget=0,
        )
        right = ReleaseExecutionPlan(
            workflow_id="abc",
            operations=(N8nOperation.READ_WORKFLOW,),
            update_budget=0,
            publish_budget=0,
        )
        self.assertEqual(
            left.fingerprint_sha256(),
            right.fingerprint_sha256(),
        )

    def test_plan_change_changes_authorization_and_fingerprint(self):
        read = ReleaseExecutionPlan(
            workflow_id="abc",
            operations=(N8nOperation.READ_WORKFLOW,),
            update_budget=0,
            publish_budget=0,
        )
        publish = ReleaseExecutionPlan(
            workflow_id="abc",
            operations=(N8nOperation.PUBLISH_EXACT_VERSION,),
            update_budget=0,
            publish_budget=1,
            exact_version_id="v2",
        )
        self.assertNotEqual(
            read.fingerprint_sha256(),
            publish.fingerprint_sha256(),
        )
        self.assertNotEqual(
            read.authorization_text(),
            publish.authorization_text(),
        )


class AuthorizationBoundaryTests(unittest.TestCase):
    def test_exact_authorization_passes(self):
        plan = ReleaseExecutionPlan(
            workflow_id="abc",
            operations=(N8nOperation.READ_WORKFLOW,),
            update_budget=0,
            publish_budget=0,
        )
        shell = ReleaseExecutionShell()
        shell.authorize(plan, plan.authorization_text())

    def test_modified_authorization_fails_closed(self):
        plan = ReleaseExecutionPlan(
            workflow_id="abc",
            operations=(N8nOperation.READ_WORKFLOW,),
            update_budget=0,
            publish_budget=0,
        )
        with self.assertRaises(AuthorizationError):
            ReleaseExecutionShell().authorize(
                plan,
                plan.authorization_text() + " ",
            )

    def test_live_execution_stays_disabled_after_valid_authorization(self):
        plan = ReleaseExecutionPlan(
            workflow_id="abc",
            operations=(N8nOperation.READ_WORKFLOW,),
            update_budget=0,
            publish_budget=0,
        )
        shell = ReleaseExecutionShell()
        with self.assertRaises(LiveExecutionDisabled):
            shell.execute_live(plan, plan.authorization_text())


if __name__ == "__main__":
    unittest.main()
