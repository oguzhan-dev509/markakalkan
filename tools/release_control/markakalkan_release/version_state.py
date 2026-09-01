from __future__ import annotations

from enum import Enum
from typing import Any, Mapping


class VersionState(str, Enum):
    INVALID = "INVALID"
    INACTIVE_NO_VERSION = "INACTIVE_NO_VERSION"
    DRAFT_UNPUBLISHED = "DRAFT_UNPUBLISHED"
    PUBLISHED_CURRENT = "PUBLISHED_CURRENT"


def classify_version_state(workflow: Mapping[str, Any]) -> VersionState:
    """Classify n8n publication state without mutation."""
    active = workflow.get("active")
    version_id = workflow.get("versionId")
    active_version_id = workflow.get("activeVersionId")

    if not isinstance(active, bool):
        return VersionState.INVALID

    if active is False:
        if active_version_id in (None, ""):
            return VersionState.INACTIVE_NO_VERSION
        return VersionState.INVALID

    if not isinstance(version_id, str) or not version_id:
        return VersionState.INVALID
    if not isinstance(active_version_id, str) or not active_version_id:
        return VersionState.INVALID

    if version_id == active_version_id:
        return VersionState.PUBLISHED_CURRENT
    return VersionState.DRAFT_UNPUBLISHED
