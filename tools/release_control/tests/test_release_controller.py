from __future__ import annotations

import copy
import unittest

from markakalkan_release.controller import (
    ReleaseController,
    ReleaseVerificationError,
)
from markakalkan_release.n8n_client import N8nWorkflowClient
from markakalkan_release.safety import MutationBudget, MutationKind
from markakalkan_release.state_machine import ReleaseState, TransitionError


class FakeTransport:
    def __init__(self):
        self.calls = []

    def request(self, method, path, body=None):
        self.calls.append((method, path, body))
        return {"ok": True}


def target() -> dict:
    return {
        "name": "parent",
        "nodes": [
            {"name": "Webhook", "parameters": {"authentication": "headerAuth"}},
            {"name": "Validate", "parameters": {"jsCode": "return items;"}},
        ],
        "connections": {},
        "settings": {"executionOrder": "v1"},
        "staticData": None,
    }


def live_draft() -> dict:
    value = copy.deepcopy(target())
    value.update({
        "active": True,
        "versionId": "draft-v2",
        "activeVersionId": "published-v1",
    })
    return value


def live_published() -> dict:
    value = copy.deepcopy(target())
    value.update({
        "active": True,
        "versionId": "draft-v2",
        "activeVersionId": "draft-v2",
    })
    return value


def make_controller(update=0, publish=0):
    transport = FakeTransport()
    budget = MutationBudget({
        MutationKind.UPDATE_DRAFT: update,
        MutationKind.PUBLISH: publish,
    })
    client = N8nWorkflowClient(
        transport=transport,
        declared_scopes=["workflow:read", "workflow:update", "workflow:activate"],
        mutation_budget=budget,
    )
    return ReleaseController(client), transport, budget


class ExistingDraftResumeTests(unittest.TestCase):
    def test_existing_exact_draft_skips_put_and_update_budget(self):
        controller, transport, budget = make_controller(update=1, publish=1)
        controller.precheck()
        controller.accept_existing_verified_draft(live_draft(), target())

        self.assertEqual(controller.state, ReleaseState.DRAFT_VERIFIED)
        self.assertEqual(transport.calls, [])
        self.assertEqual(budget.used(MutationKind.UPDATE_DRAFT), 0)

    def test_existing_draft_semantic_mismatch_fails_without_transport(self):
        controller, transport, _ = make_controller(update=1, publish=1)
        controller.precheck()
        bad = target()
        bad["nodes"][1]["parameters"]["jsCode"] = "return [];"

        with self.assertRaises(ReleaseVerificationError):
            controller.accept_existing_verified_draft(live_draft(), bad)

        self.assertEqual(controller.state, ReleaseState.PRECHECKED)
        self.assertEqual(transport.calls, [])

    def test_published_current_cannot_be_misclassified_as_existing_draft(self):
        controller, transport, _ = make_controller()
        controller.precheck()

        with self.assertRaises(ReleaseVerificationError):
            controller.accept_existing_verified_draft(live_published(), target())

        self.assertEqual(controller.state, ReleaseState.PRECHECKED)
        self.assertEqual(transport.calls, [])


class NewDraftPathTests(unittest.TestCase):
    def test_create_verify_publish_postverify_close_happy_path(self):
        controller, transport, budget = make_controller(update=1, publish=1)

        controller.precheck()
        controller.create_draft("abc", target())
        self.assertEqual(controller.state, ReleaseState.DRAFT_CREATED)

        controller.verify_created_draft(live_draft(), target())
        self.assertEqual(controller.state, ReleaseState.DRAFT_VERIFIED)

        controller.publish_exact_version("abc", "draft-v2")
        self.assertEqual(controller.state, ReleaseState.PUBLISHED)

        controller.verify_published(live_published(), target())
        self.assertEqual(controller.state, ReleaseState.POST_VERIFIED)

        controller.close()
        self.assertEqual(controller.state, ReleaseState.CLOSED)

        self.assertEqual(
            transport.calls,
            [
                (
                    "PUT",
                    "/api/v1/workflows/abc?publishIfActive=false",
                    target(),
                ),
                (
                    "POST",
                    "/api/v1/workflows/abc/publish",
                    {"versionId": "draft-v2"},
                ),
            ],
        )
        self.assertEqual(budget.used(MutationKind.UPDATE_DRAFT), 1)
        self.assertEqual(budget.used(MutationKind.PUBLISH), 1)

    def test_verify_wrong_draft_does_not_advance_state(self):
        controller, transport, _ = make_controller(update=1)
        controller.precheck()
        controller.create_draft("abc", target())

        bad_live = live_draft()
        bad_live.pop("staticData")

        with self.assertRaises(ReleaseVerificationError):
            controller.verify_created_draft(bad_live, target())

        self.assertEqual(controller.state, ReleaseState.DRAFT_CREATED)
        self.assertEqual(len(transport.calls), 1)


class StateBoundaryTests(unittest.TestCase):
    def test_publish_before_verified_is_rejected_before_transport(self):
        controller, transport, budget = make_controller(publish=1)
        controller.precheck()

        with self.assertRaises(TransitionError):
            controller.publish_exact_version("abc", "draft-v2")

        self.assertEqual(transport.calls, [])
        self.assertEqual(budget.used(MutationKind.PUBLISH), 0)

    def test_second_put_after_verified_existing_draft_is_impossible(self):
        controller, transport, budget = make_controller(update=1)
        controller.precheck()
        controller.accept_existing_verified_draft(live_draft(), target())

        with self.assertRaises(TransitionError):
            controller.create_draft("abc", target())

        self.assertEqual(transport.calls, [])
        self.assertEqual(budget.used(MutationKind.UPDATE_DRAFT), 0)

    def test_close_before_post_verify_is_rejected(self):
        controller, _, _ = make_controller()
        controller.precheck()

        with self.assertRaises(TransitionError):
            controller.close()

        self.assertEqual(controller.state, ReleaseState.PRECHECKED)


if __name__ == "__main__":
    unittest.main()
