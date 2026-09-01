# MarkaKalkan Release Control Plane

Permanent release-control primitives extracted from production lessons.

## Phase 1B rules

- Artifact identity and semantic equality are different concepts.
- Optional JSON field presence is semantic: MISSING != NULL != VALUE.
- Workflow node array order is representational for semantic comparison.
- Release transitions are explicit and fail closed.
- This phase has no network or n8n access.
