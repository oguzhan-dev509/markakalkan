from __future__ import annotations

import copy
import unittest

from markakalkan_release.hashing import sha256_json
from markakalkan_release.optional_field import OptionalFieldState, classify_optional_field
from markakalkan_release.state_machine import ReleaseState, TransitionError, ensure_transition
from markakalkan_release.workflow_semantics import representation_diff, workflow_semantic_diff


def workflow() -> dict:
    return {
        "name": "parent",
        "nodes": [
            {"name": "Webhook", "parameters": {"authentication": "headerAuth"}, "type": "webhook"},
            {"name": "Validate", "parameters": {"jsCode": "return items;"}, "type": "code"},
        ],
        "connections": {"Webhook": {"main": [[{"node": "Validate"}]]}},
        "settings": {"executionOrder": "v1"},
        "staticData": None,
    }


class OptionalFieldTests(unittest.TestCase):
    def test_missing_null_value_are_three_distinct_states(self):
        self.assertEqual(classify_optional_field({}, "staticData"), OptionalFieldState.MISSING)
        self.assertEqual(classify_optional_field({"staticData": None}, "staticData"), OptionalFieldState.NULL)
        self.assertEqual(classify_optional_field({"staticData": {}}, "staticData"), OptionalFieldState.VALUE)

    def test_missing_is_not_null(self):
        self.assertNotEqual(
            classify_optional_field({}, "staticData"),
            classify_optional_field({"staticData": None}, "staticData"),
        )


class HashingTests(unittest.TestCase):
    def test_dict_key_order_does_not_change_canonical_hash(self):
        self.assertEqual(sha256_json({"a": 1, "b": 2}), sha256_json({"b": 2, "a": 1}))

    def test_list_order_does_change_canonical_hash(self):
        self.assertNotEqual(sha256_json({"nodes": ["a", "b"]}), sha256_json({"nodes": ["b", "a"]}))

    def test_missing_and_explicit_null_have_different_hashes(self):
        self.assertNotEqual(sha256_json({}), sha256_json({"staticData": None}))


class WorkflowSemanticTests(unittest.TestCase):
    def test_node_order_is_not_workflow_semantic_difference(self):
        left = workflow()
        right = copy.deepcopy(left)
        right["nodes"] = list(reversed(right["nodes"]))
        self.assertNotEqual(sha256_json(left), sha256_json(right))
        self.assertTrue(representation_diff(left, right))
        self.assertEqual(workflow_semantic_diff(left, right), [])

    def test_staticdata_presence_is_semantic(self):
        left = workflow()
        right = copy.deepcopy(left)
        right.pop("staticData")
        self.assertEqual(workflow_semantic_diff(left, right), ["$.staticData:PRESENCE"])

    def test_validator_change_is_semantic(self):
        left = workflow()
        right = copy.deepcopy(left)
        right["nodes"][1]["parameters"]["jsCode"] = "return [];"
        self.assertEqual(
            workflow_semantic_diff(left, right),
            ["$.nodesByName[Validate].parameters.jsCode"],
        )


class ReleaseStateMachineTests(unittest.TestCase):
    def test_happy_path(self):
        path = [
            ReleaseState.LOCKED,
            ReleaseState.PRECHECKED,
            ReleaseState.DRAFT_CREATED,
            ReleaseState.DRAFT_VERIFIED,
            ReleaseState.PUBLISHED,
            ReleaseState.POST_VERIFIED,
            ReleaseState.CLOSED,
        ]
        for current, target in zip(path, path[1:]):
            ensure_transition(current, target)

    def test_cannot_publish_unverified_draft(self):
        with self.assertRaises(TransitionError):
            ensure_transition(ReleaseState.DRAFT_CREATED, ReleaseState.PUBLISHED)

    def test_cannot_put_again_after_draft_verified(self):
        with self.assertRaises(TransitionError):
            ensure_transition(ReleaseState.DRAFT_VERIFIED, ReleaseState.DRAFT_CREATED)

    def test_closed_is_terminal(self):
        with self.assertRaises(TransitionError):
            ensure_transition(ReleaseState.CLOSED, ReleaseState.PRECHECKED)


if __name__ == "__main__":
    unittest.main()
