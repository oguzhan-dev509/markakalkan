from __future__ import annotations

import copy
import itertools
import unittest

from markakalkan_release.hashing import sha256_json
from markakalkan_release.optional_field import OptionalFieldState, classify_optional_field
from markakalkan_release.state_machine import ReleaseState, TransitionError, ensure_transition
from markakalkan_release.version_state import VersionState, classify_version_state
from markakalkan_release.workflow_semantics import representation_diff, workflow_semantic_diff


def base_workflow() -> dict:
    return {
        "name": "parent",
        "nodes": [
            {"name": "A", "parameters": {"x": 1}},
            {"name": "B", "parameters": {"x": 2}},
            {"name": "C", "parameters": {"x": 3}},
        ],
        "connections": {},
        "settings": {"executionOrder": "v1"},
        "staticData": None,
    }


class OptionalFieldMatrixTests(unittest.TestCase):
    def test_missing_null_value_matrix_is_pairwise_distinct(self):
        samples = {
            OptionalFieldState.MISSING: {},
            OptionalFieldState.NULL: {"staticData": None},
            OptionalFieldState.VALUE: {"staticData": {}},
        }
        for expected_state, sample in samples.items():
            self.assertEqual(classify_optional_field(sample, "staticData"), expected_state)
        for left, right in itertools.combinations(samples, 2):
            self.assertNotEqual(
                classify_optional_field(samples[left], "staticData"),
                classify_optional_field(samples[right], "staticData"),
            )

    def test_missing_null_value_hashes_are_all_distinct(self):
        hashes = {
            sha256_json({}),
            sha256_json({"staticData": None}),
            sha256_json({"staticData": {}}),
        }
        self.assertEqual(len(hashes), 3)


class NodeOrderInvariantTests(unittest.TestCase):
    def test_all_six_node_permutations_are_semantically_equal(self):
        original = base_workflow()
        names = [node["name"] for node in original["nodes"]]
        hashes = set()
        for order in itertools.permutations(names):
            candidate = copy.deepcopy(original)
            mapping = {node["name"]: node for node in candidate["nodes"]}
            candidate["nodes"] = [mapping[name] for name in order]
            hashes.add(sha256_json(candidate))
            self.assertEqual(workflow_semantic_diff(original, candidate), [])
        self.assertEqual(len(hashes), 6)

    def test_parameter_change_is_not_masked_by_reordering(self):
        left = base_workflow()
        right = copy.deepcopy(left)
        right["nodes"] = list(reversed(right["nodes"]))
        for node in right["nodes"]:
            if node["name"] == "B":
                node["parameters"]["x"] = 999
        self.assertEqual(
            workflow_semantic_diff(left, right),
            ["$.nodesByName[B].parameters.x"],
        )

    def test_duplicate_node_names_fail_closed(self):
        left = base_workflow()
        right = copy.deepcopy(left)
        right["nodes"][1]["name"] = "A"
        with self.assertRaises(ValueError):
            workflow_semantic_diff(left, right)


class RepresentationVsSemanticTests(unittest.TestCase):
    def test_representation_detects_order_semantics_ignore_order(self):
        left = base_workflow()
        right = copy.deepcopy(left)
        right["nodes"] = [right["nodes"][2], right["nodes"][0], right["nodes"][1]]
        self.assertTrue(representation_diff(left, right))
        self.assertEqual(workflow_semantic_diff(left, right), [])
        self.assertNotEqual(sha256_json(left), sha256_json(right))

    def test_staticdata_missing_vs_null_survives_python_get_trap(self):
        left = base_workflow()
        right = copy.deepcopy(left)
        right.pop("staticData")
        self.assertIsNone(left.get("staticData"))
        self.assertIsNone(right.get("staticData"))
        self.assertEqual(workflow_semantic_diff(left, right), ["$.staticData:PRESENCE"])


class VersionStateMatrixTests(unittest.TestCase):
    def test_published_current(self):
        self.assertEqual(
            classify_version_state({"active": True, "versionId": "v2", "activeVersionId": "v2"}),
            VersionState.PUBLISHED_CURRENT,
        )

    def test_unpublished_draft(self):
        self.assertEqual(
            classify_version_state({"active": True, "versionId": "v3", "activeVersionId": "v2"}),
            VersionState.DRAFT_UNPUBLISHED,
        )

    def test_inactive_without_active_version(self):
        self.assertEqual(
            classify_version_state({"active": False, "versionId": "v3", "activeVersionId": None}),
            VersionState.INACTIVE_NO_VERSION,
        )

    def test_active_missing_version_invalid(self):
        self.assertEqual(
            classify_version_state({"active": True, "versionId": None, "activeVersionId": "v2"}),
            VersionState.INVALID,
        )

    def test_active_missing_active_version_invalid(self):
        self.assertEqual(
            classify_version_state({"active": True, "versionId": "v2", "activeVersionId": None}),
            VersionState.INVALID,
        )

    def test_inactive_with_active_version_invalid(self):
        self.assertEqual(
            classify_version_state({"active": False, "versionId": "v2", "activeVersionId": "v2"}),
            VersionState.INVALID,
        )

    def test_missing_active_boolean_invalid(self):
        self.assertEqual(
            classify_version_state({"versionId": "v2", "activeVersionId": "v2"}),
            VersionState.INVALID,
        )


class TransitionMatrixTests(unittest.TestCase):
    def test_only_seven_safe_forward_transitions_are_allowed(self):
        states = list(ReleaseState)
        allowed = set()
        for current in states:
            for target in states:
                try:
                    ensure_transition(current, target)
                except TransitionError:
                    continue
                allowed.add((current, target))
        self.assertEqual(
            allowed,
            {
                (ReleaseState.LOCKED, ReleaseState.PRECHECKED),
                (ReleaseState.PRECHECKED, ReleaseState.DRAFT_CREATED),
                (ReleaseState.PRECHECKED, ReleaseState.DRAFT_VERIFIED),
                (ReleaseState.DRAFT_CREATED, ReleaseState.DRAFT_VERIFIED),
                (ReleaseState.DRAFT_VERIFIED, ReleaseState.PUBLISHED),
                (ReleaseState.PUBLISHED, ReleaseState.POST_VERIFIED),
                (ReleaseState.POST_VERIFIED, ReleaseState.CLOSED),
            },
        )

    def test_all_self_transitions_fail_closed(self):
        for state in ReleaseState:
            with self.assertRaises(TransitionError):
                ensure_transition(state, state)


if __name__ == "__main__":
    unittest.main()
