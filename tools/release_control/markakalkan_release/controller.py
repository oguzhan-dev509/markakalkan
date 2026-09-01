from __future__ import annotations

from dataclasses import dataclass
from typing import Any, Mapping

from .n8n_client import N8nWorkflowClient
from .state_machine import ReleaseState, TransitionError, ensure_transition
from .version_state import VersionState, classify_version_state
from .workflow_semantics import workflow_semantic_diff


class ReleaseVerificationError(ValueError):
    pass


@dataclass
class ReleaseController:
    """
    Pure orchestration layer over the permanent release primitives.

    It deliberately has no network implementation of its own. All I/O goes
    through an injected N8nWorkflowClient/transport. Invalid state transitions
    are rejected before any client call is attempted.
    """

    client: N8nWorkflowClient
    state: ReleaseState = ReleaseState.LOCKED

    def _transition(self, target: ReleaseState) -> None:
        ensure_transition(self.state, target)
        self.state = target

    def precheck(self) -> None:
        self._transition(ReleaseState.PRECHECKED)

    @staticmethod
    def _require_semantic_match(
        live_workflow: Mapping[str, Any],
        target_workflow: Mapping[str, Any],
    ) -> None:
        if not isinstance(live_workflow, Mapping):
            raise ReleaseVerificationError("live workflow must be an object")
        if not isinstance(target_workflow, Mapping):
            raise ReleaseVerificationError("target workflow must be an object")

        diffs = workflow_semantic_diff(
            dict(live_workflow),
            dict(target_workflow),
        )
        if diffs:
            raise ReleaseVerificationError(
                "workflow semantic mismatch: " + ",".join(diffs)
            )

    def accept_existing_verified_draft(
        self,
        live_workflow: Mapping[str, Any],
        target_workflow: Mapping[str, Any],
    ) -> None:
        """
        Resume safely when the exact target already exists as an unpublished
        draft. No PUT is performed and no update budget is consumed.
        """
        ensure_transition(self.state, ReleaseState.DRAFT_VERIFIED)
        if classify_version_state(live_workflow) != VersionState.DRAFT_UNPUBLISHED:
            raise ReleaseVerificationError(
                "existing workflow is not an unpublished draft"
            )
        self._require_semantic_match(live_workflow, target_workflow)
        self.state = ReleaseState.DRAFT_VERIFIED

    def create_draft(
        self,
        workflow_id: str,
        target_workflow: Mapping[str, Any],
    ) -> Mapping[str, Any]:
        ensure_transition(self.state, ReleaseState.DRAFT_CREATED)
        response = self.client.save_draft(workflow_id, target_workflow)
        self.state = ReleaseState.DRAFT_CREATED
        return response

    def verify_created_draft(
        self,
        live_workflow: Mapping[str, Any],
        target_workflow: Mapping[str, Any],
    ) -> None:
        ensure_transition(self.state, ReleaseState.DRAFT_VERIFIED)
        if classify_version_state(live_workflow) != VersionState.DRAFT_UNPUBLISHED:
            raise ReleaseVerificationError(
                "created workflow is not an unpublished draft"
            )
        self._require_semantic_match(live_workflow, target_workflow)
        self.state = ReleaseState.DRAFT_VERIFIED

    def publish_exact_version(
        self,
        workflow_id: str,
        version_id: str,
    ) -> Mapping[str, Any]:
        ensure_transition(self.state, ReleaseState.PUBLISHED)
        response = self.client.publish_exact_version(workflow_id, version_id)
        self.state = ReleaseState.PUBLISHED
        return response

    def verify_published(
        self,
        live_workflow: Mapping[str, Any],
        target_workflow: Mapping[str, Any],
    ) -> None:
        ensure_transition(self.state, ReleaseState.POST_VERIFIED)
        if classify_version_state(live_workflow) != VersionState.PUBLISHED_CURRENT:
            raise ReleaseVerificationError(
                "workflow is not published-current"
            )
        self._require_semantic_match(live_workflow, target_workflow)
        self.state = ReleaseState.POST_VERIFIED

    def close(self) -> None:
        self._transition(ReleaseState.CLOSED)
