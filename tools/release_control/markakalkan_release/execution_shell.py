from __future__ import annotations

from dataclasses import dataclass
from enum import Enum
from typing import Any, Mapping, Protocol, Sequence

from .hashing import sha256_json
from .n8n_client import N8nOperation, REQUIRED_SCOPE
from .safety import MutationKind


class ExecutionMode(str, Enum):
    DRY_RUN = "DRY_RUN"
    LIVE_READ_ONLY = "LIVE_READ_ONLY"
    LIVE = "LIVE"


class AuthorizationError(PermissionError):
    pass


class LiveExecutionDisabled(RuntimeError):
    pass


class ReadOnlyLivePlanError(RuntimeError):
    pass


class _ReadOnlyWorkflowClient(Protocol):
    def get_workflow(self, workflow_id: str) -> Mapping[str, Any]:
        ...


@dataclass(frozen=True)
class ReleaseExecutionPlan:
    workflow_id: str
    operations: tuple[N8nOperation, ...]
    update_budget: int
    publish_budget: int
    exact_version_id: str | None = None

    def __post_init__(self) -> None:
        if not isinstance(self.workflow_id, str) or not self.workflow_id:
            raise ValueError("workflow_id required")
        if not self.operations:
            raise ValueError("at least one operation required")
        if self.update_budget < 0 or self.publish_budget < 0:
            raise ValueError("mutation budgets must be non-negative")

        update_ops = sum(
            1 for op in self.operations
            if op == N8nOperation.SAVE_DRAFT
        )
        publish_ops = sum(
            1 for op in self.operations
            if op == N8nOperation.PUBLISH_EXACT_VERSION
        )

        if update_ops > self.update_budget:
            raise ValueError("update operation count exceeds update budget")
        if publish_ops > self.publish_budget:
            raise ValueError("publish operation count exceeds publish budget")
        if publish_ops and not self.exact_version_id:
            raise ValueError("publish requires exact_version_id")
        if not publish_ops and self.exact_version_id is not None:
            raise ValueError("exact_version_id only valid for publish plan")

    def required_scopes(self) -> tuple[str, ...]:
        return tuple(sorted({
            REQUIRED_SCOPE[operation]
            for operation in self.operations
        }))

    def as_dict(self) -> dict[str, Any]:
        return {
            "workflowId": self.workflow_id,
            "operations": [op.value for op in self.operations],
            "requiredScopes": list(self.required_scopes()),
            "mutationBudget": {
                MutationKind.UPDATE_DRAFT.value: self.update_budget,
                MutationKind.PUBLISH.value: self.publish_budget,
            },
            "exactVersionId": self.exact_version_id,
        }

    def fingerprint_sha256(self) -> str:
        return sha256_json(self.as_dict())

    def authorization_text(self) -> str:
        operations = ",".join(op.value for op in self.operations)
        scopes = ",".join(self.required_scopes())
        version = self.exact_version_id or "NONE"
        return (
            "MARKAKALKAN RELEASE AUTHORIZED; "
            f"WORKFLOW_ID={self.workflow_id}; "
            f"OPERATIONS={operations}; "
            f"SCOPES={scopes}; "
            f"UPDATE_BUDGET={self.update_budget}; "
            f"PUBLISH_BUDGET={self.publish_budget}; "
            f"EXACT_VERSION_ID={version}; "
            f"PLAN_SHA256={self.fingerprint_sha256()}; "
            "NO_BLIND_RETRY; NO_AUTOMATIC_ROLLBACK"
        )


@dataclass(frozen=True)
class DryRunReceipt:
    mode: str
    plan: Mapping[str, Any]
    plan_sha256: str
    required_scopes: Sequence[str]
    network_call_count: int
    mutation_count: int
    authorization_required_for_live: str

    def as_dict(self) -> dict[str, Any]:
        return {
            "mode": self.mode,
            "plan": dict(self.plan),
            "planSha256": self.plan_sha256,
            "requiredScopes": list(self.required_scopes),
            "networkCallCount": self.network_call_count,
            "mutationCount": self.mutation_count,
            "authorizationRequiredForLive": self.authorization_required_for_live,
        }


@dataclass(frozen=True)
class LiveReadOnlyReceipt:
    mode: str
    workflow_id: str
    plan_sha256: str
    workflow_object_sha256: str
    network_call_count: int
    mutation_count: int

    def as_dict(self) -> dict[str, Any]:
        return {
            "mode": self.mode,
            "workflowId": self.workflow_id,
            "planSha256": self.plan_sha256,
            "workflowObjectSha256": self.workflow_object_sha256,
            "networkCallCount": self.network_call_count,
            "mutationCount": self.mutation_count,
        }


class ReleaseExecutionShell:
    """
    Execution boundary for release plans.

    Phase 3B permits exactly one live READ_WORKFLOW operation after exact
    authorization. Any mutation-capable live plan remains disabled.
    """

    def dry_run(self, plan: ReleaseExecutionPlan) -> DryRunReceipt:
        return DryRunReceipt(
            mode=ExecutionMode.DRY_RUN.value,
            plan=plan.as_dict(),
            plan_sha256=plan.fingerprint_sha256(),
            required_scopes=plan.required_scopes(),
            network_call_count=0,
            mutation_count=0,
            authorization_required_for_live=plan.authorization_text(),
        )

    def authorize(
        self,
        plan: ReleaseExecutionPlan,
        typed_authorization: str,
    ) -> None:
        expected = plan.authorization_text()
        if typed_authorization != expected:
            raise AuthorizationError("authorization text mismatch")

    @staticmethod
    def _assert_single_read_only_plan(plan: ReleaseExecutionPlan) -> None:
        if plan.operations != (N8nOperation.READ_WORKFLOW,):
            raise ReadOnlyLivePlanError(
                "live read-only path requires exactly one READ_WORKFLOW operation"
            )
        if plan.update_budget != 0 or plan.publish_budget != 0:
            raise ReadOnlyLivePlanError(
                "live read-only path requires zero mutation budgets"
            )
        if plan.exact_version_id is not None:
            raise ReadOnlyLivePlanError(
                "live read-only path does not accept exact_version_id"
            )
        if plan.required_scopes() != ("workflow:read",):
            raise ReadOnlyLivePlanError(
                "live read-only path requires workflow:read only"
            )

    def execute_live_read_only(
        self,
        plan: ReleaseExecutionPlan,
        typed_authorization: str,
        client: _ReadOnlyWorkflowClient,
    ) -> tuple[Mapping[str, Any], LiveReadOnlyReceipt]:
        self.authorize(plan, typed_authorization)
        self._assert_single_read_only_plan(plan)

        workflow = client.get_workflow(plan.workflow_id)
        if not isinstance(workflow, Mapping):
            raise TypeError("workflow response must be an object")

        receipt = LiveReadOnlyReceipt(
            mode=ExecutionMode.LIVE_READ_ONLY.value,
            workflow_id=plan.workflow_id,
            plan_sha256=plan.fingerprint_sha256(),
            workflow_object_sha256=sha256_json(workflow),
            network_call_count=1,
            mutation_count=0,
        )
        return workflow, receipt

    def execute_live(
        self,
        plan: ReleaseExecutionPlan,
        typed_authorization: str,
    ) -> None:
        self.authorize(plan, typed_authorization)
        raise LiveExecutionDisabled(
            "mutation-capable live execution remains disabled"
        )
