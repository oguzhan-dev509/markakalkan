from __future__ import annotations

import copy
import unittest

from markakalkan_release.controller import ReleaseController, ReleaseVerificationError
from markakalkan_release.execution_shell import (
    AuthorizationError,
    ReleaseExecutionPlan,
    ReleaseExecutionShell,
)
from markakalkan_release.n8n_client import N8nOperation, N8nWorkflowClient
from markakalkan_release.safety import (
    MutationBudget,
    MutationBudgetExceeded,
    MutationKind,
)
from markakalkan_release.state_machine import ReleaseState


def target() -> dict:
    return {
        "name": "parent",
        "nodes": [
            {"name": "Webhook", "parameters": {"authentication": "headerAuth"}},
            {"name": "Validate", "parameters": {"jsCode": "return normalized;"}},
        ],
        "connections": {},
        "settings": {"executionOrder": "v1"},
        "staticData": None,
    }


def draft_state() -> dict:
    value = copy.deepcopy(target())
    value.update({
        "active": True,
        "versionId": "draft-v2",
        "activeVersionId": "published-v1",
    })
    return value


def published_state() -> dict:
    value = copy.deepcopy(target())
    value.update({
        "active": True,
        "versionId": "draft-v2",
        "activeVersionId": "draft-v2",
    })
    return value


class ScriptedTransport:
    """
    Pure local transport simulator.
    No socket, HTTP client, or external resource is used.
    """
    def __init__(self, workflow_reads):
        self.workflow_reads = list(workflow_reads)
        self.calls = []

    def request(self, method, path, body=None):
        self.calls.append((method, path, body))
        if method == "GET":
            if not self.workflow_reads:
                raise AssertionError("unexpected extra workflow read")
            return self.workflow_reads.pop(0)
        if method == "PUT":
            return {"ok": True, "saved": True}
        if method == "POST":
            return {"ok": True, "published": True}
        raise AssertionError("unexpected method")


def client_for(transport, *, update=0, publish=0, scopes=None):
    if scopes is None:
        scopes = ["workflow:read", "workflow:update", "workflow:activate"]
    budget = MutationBudget({
        MutationKind.UPDATE_DRAFT: update,
        MutationKind.PUBLISH: publish,
    })
    client = N8nWorkflowClient(
        transport=transport,
        declared_scopes=scopes,
        mutation_budget=budget,
    )
    return client, budget


class ExistingDraftPublishOnlyScenario(unittest.TestCase):
    def test_full_publish_only_flow_has_no_put(self):
        plan = ReleaseExecutionPlan(
            workflow_id="abc",
            operations=(
                N8nOperation.READ_WORKFLOW,
                N8nOperation.PUBLISH_EXACT_VERSION,
                N8nOperation.READ_WORKFLOW,
            ),
            update_budget=0,
            publish_budget=1,
            exact_version_id="draft-v2",
        )
        shell = ReleaseExecutionShell()
        receipt = shell.dry_run(plan)

        self.assertEqual(receipt.network_call_count, 0)
        self.assertEqual(receipt.mutation_count, 0)
        self.assertEqual(
            plan.required_scopes(),
            ("workflow:activate", "workflow:read"),
        )

        transport = ScriptedTransport([draft_state(), published_state()])
        client, budget = client_for(
            transport,
            update=0,
            publish=1,
            scopes=list(plan.required_scopes()),
        )
        controller = ReleaseController(client)

        controller.precheck()
        live_before = client.get_workflow("abc")
        controller.accept_existing_verified_draft(live_before, target())
        controller.publish_exact_version("abc", "draft-v2")
        live_after = client.get_workflow("abc")
        controller.verify_published(live_after, target())
        controller.close()

        self.assertEqual(controller.state, ReleaseState.CLOSED)
        self.assertEqual(budget.used(MutationKind.UPDATE_DRAFT), 0)
        self.assertEqual(budget.used(MutationKind.PUBLISH), 1)
        self.assertEqual(
            [call[0] for call in transport.calls],
            ["GET", "POST", "GET"],
        )
        self.assertNotIn("PUT", [call[0] for call in transport.calls])


class NewDraftScenario(unittest.TestCase):
    def test_full_new_draft_flow_is_get_put_get_post_get(self):
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
            exact_version_id="draft-v2",
        )
        shell = ReleaseExecutionShell()
        receipt = shell.dry_run(plan)
        self.assertEqual(receipt.network_call_count, 0)

        transport = ScriptedTransport([
            published_state(),
            draft_state(),
            published_state(),
        ])
        client, budget = client_for(
            transport,
            update=1,
            publish=1,
            scopes=list(plan.required_scopes()),
        )
        controller = ReleaseController(client)

        controller.precheck()
        client.get_workflow("abc")
        controller.create_draft("abc", target())
        live_draft = client.get_workflow("abc")
        controller.verify_created_draft(live_draft, target())
        controller.publish_exact_version("abc", "draft-v2")
        live_final = client.get_workflow("abc")
        controller.verify_published(live_final, target())
        controller.close()

        self.assertEqual(
            [call[0] for call in transport.calls],
            ["GET", "PUT", "GET", "POST", "GET"],
        )
        self.assertEqual(budget.used(MutationKind.UPDATE_DRAFT), 1)
        self.assertEqual(budget.used(MutationKind.PUBLISH), 1)


class FailClosedScenarios(unittest.TestCase):
    def test_wrong_authorization_causes_zero_transport_calls(self):
        plan = ReleaseExecutionPlan(
            workflow_id="abc",
            operations=(N8nOperation.READ_WORKFLOW,),
            update_budget=0,
            publish_budget=0,
        )
        shell = ReleaseExecutionShell()
        transport = ScriptedTransport([published_state()])

        with self.assertRaises(AuthorizationError):
            shell.authorize(plan, "WRONG")

        self.assertEqual(transport.calls, [])

    def test_semantic_mismatch_blocks_publish(self):
        transport = ScriptedTransport([draft_state()])
        client, budget = client_for(
            transport,
            update=0,
            publish=1,
            scopes=["workflow:read", "workflow:activate"],
        )
        controller = ReleaseController(client)
        controller.precheck()

        live = client.get_workflow("abc")
        bad_target = target()
        bad_target["nodes"][1]["parameters"]["jsCode"] = "return [];"

        with self.assertRaises(ReleaseVerificationError):
            controller.accept_existing_verified_draft(live, bad_target)

        self.assertEqual(
            [call[0] for call in transport.calls],
            ["GET"],
        )
        self.assertEqual(budget.used(MutationKind.PUBLISH), 0)

    def test_second_publish_is_blocked_before_transport(self):
        transport = ScriptedTransport([])
        client, budget = client_for(
            transport,
            update=0,
            publish=1,
            scopes=["workflow:activate"],
        )
        client.publish_exact_version("abc", "draft-v2")

        with self.assertRaises(MutationBudgetExceeded):
            client.publish_exact_version("abc", "draft-v2")

        self.assertEqual(
            [call[0] for call in transport.calls],
            ["POST"],
        )
        self.assertEqual(budget.used(MutationKind.PUBLISH), 1)

    def test_exact_draft_resume_consumes_no_update_scope_or_budget(self):
        plan = ReleaseExecutionPlan(
            workflow_id="abc",
            operations=(
                N8nOperation.READ_WORKFLOW,
                N8nOperation.PUBLISH_EXACT_VERSION,
            ),
            update_budget=0,
            publish_budget=1,
            exact_version_id="draft-v2",
        )
        self.assertNotIn("workflow:update", plan.required_scopes())

        transport = ScriptedTransport([draft_state()])
        client, budget = client_for(
            transport,
            update=0,
            publish=1,
            scopes=list(plan.required_scopes()),
        )
        controller = ReleaseController(client)
        controller.precheck()
        controller.accept_existing_verified_draft(
            client.get_workflow("abc"),
            target(),
        )

        self.assertEqual(budget.used(MutationKind.UPDATE_DRAFT), 0)
        self.assertEqual([call[0] for call in transport.calls], ["GET"])


if __name__ == "__main__":
    unittest.main()
