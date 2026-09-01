from __future__ import annotations

import copy
import hashlib
import json
from pathlib import Path
import unittest

from markakalkan_release.controller import ReleaseController, ReleaseVerificationError
from markakalkan_release.n8n_client import N8nWorkflowClient
from markakalkan_release.optional_field import OptionalFieldState, classify_optional_field
from markakalkan_release.safety import MutationBudget, MutationKind
from markakalkan_release.state_machine import ReleaseState
from markakalkan_release.version_state import VersionState, classify_version_state
from markakalkan_release.workflow_semantics import workflow_semantic_diff


FIXTURE_PATH = Path(__file__).with_name("fixtures") / "brt_0cs_compatibility.json"


class FakeTransport:
    def __init__(self):
        self.calls = []

    def request(self, method, path, body=None):
        self.calls.append((method, path, body))
        return {"ok": True}


def fixture():
    return json.loads(FIXTURE_PATH.read_text(encoding="utf-8"))


def target():
    # Minimal behavior-equivalent regression model for the historical failure class.
    return {
        "name": "MarkaKalkan Public Lite Risk Scan Gateway - V1",
        "nodes": [
            {
                "name": "Public Lite Dispatch Webhook",
                "parameters": {"authentication": "headerAuth"},
            },
            {
                "name": "Validate Public Lite Dispatch",
                "parameters": {"jsCode": "return normalizedMaterializedBody;"},
            },
            {
                "name": "Build Durable Dispatch Receipt",
                "parameters": {"jsCode": "return receipt;"},
            },
        ],
        "connections": {},
        "settings": {"executionOrder": "v1"},
        "staticData": None,
    }


def draft_state():
    value = copy.deepcopy(target())
    value.update({
        "active": True,
        "versionId": "corrected-draft-v2",
        "activeVersionId": "old-published-v1",
    })
    return value


def published_state():
    value = copy.deepcopy(target())
    value.update({
        "active": True,
        "versionId": "corrected-draft-v2",
        "activeVersionId": "corrected-draft-v2",
    })
    return value


def make_controller():
    transport = FakeTransport()
    budget = MutationBudget({
        MutationKind.UPDATE_DRAFT: 1,
        MutationKind.PUBLISH: 1,
    })
    client = N8nWorkflowClient(
        transport=transport,
        declared_scopes=["workflow:read", "workflow:update", "workflow:activate"],
        mutation_budget=budget,
    )
    return ReleaseController(client), transport, budget


class BRTFixtureIntegrityTests(unittest.TestCase):
    def test_fixture_locks_final_production_fingerprints(self):
        f = fixture()
        self.assertTrue(f["closed"])
        self.assertEqual(
            f["repositoryHead"],
            "851d4a3bc83b0185b39cafc2ba7841d9c4455498",
        )
        self.assertEqual(
            f["final"]["publishedVersionIdSha256"],
            "4240bfdded213cd20aa4ff0b21c227c2dbd98feff7f485176c158f8f05fff8da",
        )
        self.assertEqual(
            f["final"]["payloadSha256"],
            "21d1b98d700d4cc986b7eb19da9a6cbdd49c5f4bad365729de147fd2937742bb",
        )
        self.assertEqual(
            f["final"]["validatorSha256"],
            "6ed5d1191e22545a832a5fc24b96e1c8ca993db9e4021b9aeff3e32643a67afb",
        )
        self.assertEqual(
            f["final"]["receiptSha256"],
            "3d23ccd547326293a756fd9d82183a2ee80bd1acb7c6d233cacf6b8f8f75dd29",
        )

    def test_fixture_locks_historical_root_cause(self):
        f = fixture()
        self.assertEqual(f["historical"]["rootCause"], "staticData_presence")
        self.assertIs(f["historical"]["nodeOrderComponentPresent"], False)
        self.assertNotEqual(
            f["historical"]["flawed5ITargetPayloadSha256"],
            f["historical"]["correctedRuntimeTargetPayloadSha256"],
        )


class BRTStaticDataRegressionTests(unittest.TestCase):
    def test_flawed_5i_shape_missing_staticdata_is_rejected(self):
        corrected = target()
        flawed = copy.deepcopy(corrected)
        flawed.pop("staticData")

        self.assertEqual(
            classify_optional_field(corrected, "staticData"),
            OptionalFieldState.NULL,
        )
        self.assertEqual(
            classify_optional_field(flawed, "staticData"),
            OptionalFieldState.MISSING,
        )
        self.assertEqual(
            workflow_semantic_diff(flawed, corrected),
            ["$.staticData:PRESENCE"],
        )

    def test_get_style_null_check_cannot_replace_presence_check(self):
        corrected = target()
        flawed = copy.deepcopy(corrected)
        flawed.pop("staticData")

        self.assertIsNone(corrected.get("staticData"))
        self.assertIsNone(flawed.get("staticData"))
        self.assertNotEqual(
            classify_optional_field(corrected, "staticData"),
            classify_optional_field(flawed, "staticData"),
        )


class BRTStateCompatibilityTests(unittest.TestCase):
    def test_5j_post_put_state_is_unpublished_draft(self):
        self.assertEqual(
            classify_version_state(draft_state()),
            VersionState.DRAFT_UNPUBLISHED,
        )

    def test_5m_and_5n_state_is_published_current(self):
        self.assertEqual(
            classify_version_state(published_state()),
            VersionState.PUBLISHED_CURRENT,
        )

    def test_5m_path_resumes_existing_exact_draft_without_second_put(self):
        controller, transport, budget = make_controller()

        controller.precheck()
        controller.accept_existing_verified_draft(draft_state(), target())
        self.assertEqual(controller.state, ReleaseState.DRAFT_VERIFIED)

        controller.publish_exact_version("rwEz3BWN636OJU2B", "corrected-draft-v2")
        controller.verify_published(published_state(), target())
        controller.close()

        self.assertEqual(controller.state, ReleaseState.CLOSED)
        self.assertEqual(budget.used(MutationKind.UPDATE_DRAFT), 0)
        self.assertEqual(budget.used(MutationKind.PUBLISH), 1)
        self.assertEqual(
            transport.calls,
            [
                (
                    "POST",
                    "/api/v1/workflows/rwEz3BWN636OJU2B/publish",
                    {"versionId": "corrected-draft-v2"},
                )
            ],
        )

    def test_flawed_existing_draft_cannot_be_accepted(self):
        controller, transport, budget = make_controller()
        controller.precheck()

        flawed_live = draft_state()
        flawed_live.pop("staticData")

        with self.assertRaises(ReleaseVerificationError):
            controller.accept_existing_verified_draft(flawed_live, target())

        self.assertEqual(controller.state, ReleaseState.PRECHECKED)
        self.assertEqual(transport.calls, [])
        self.assertEqual(budget.used(MutationKind.UPDATE_DRAFT), 0)
        self.assertEqual(budget.used(MutationKind.PUBLISH), 0)


class BRTPermanentSafetyRuleTests(unittest.TestCase):
    def test_do_not_rerun_rules_are_fixture_locked(self):
        rules = fixture()["permanentRules"]
        self.assertIs(rules["brt0cs4bRerunAllowed"], False)
        self.assertIs(rules["brt0cs5jRerunAllowed"], False)
        self.assertIs(rules["brt0cs5mRerunAllowed"], False)
        self.assertIs(rules["noBlindRetry"], True)
        self.assertIs(rules["existingExactDraftMustNotBeRewritten"], True)


if __name__ == "__main__":
    unittest.main()
