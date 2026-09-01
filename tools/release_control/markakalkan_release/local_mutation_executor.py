from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Any, Mapping, Protocol

from .execution_shell import AuthorizationError, ReleaseExecutionPlan
from .hashing import sha256_json
from .n8n_client import N8nOperation
from .safety import acquire_single_use_lock


class LocalSimulationOnlyError(RuntimeError):
    pass


class LocalMutationPlanError(RuntimeError):
    pass


class _SimulationMutationClient(Protocol):
    simulation_only: bool

    def get_workflow(self, workflow_id: str) -> Mapping[str, Any]:
        ...

    def save_draft(
        self,
        workflow_id: str,
        payload: Mapping[str, Any],
    ) -> Mapping[str, Any]:
        ...

    def publish_exact_version(
        self,
        workflow_id: str,
        version_id: str,
    ) -> Mapping[str, Any]:
        ...


@dataclass(frozen=True)
class LocalMutationExecutionReceipt:
    mode: str
    workflow_id: str
    plan_sha256: str
    operation_count: int
    mutation_operation_count: int
    final_object_sha256: str
    single_use_lock_path: str

    def as_dict(self) -> dict[str, Any]:
        return {
            "mode": self.mode,
            "workflowId": self.workflow_id,
            "planSha256": self.plan_sha256,
            "operationCount": self.operation_count,
            "mutationOperationCount": self.mutation_operation_count,
            "finalObjectSha256": self.final_object_sha256,
            "singleUseLockPath": self.single_use_lock_path,
        }


class LocalMutationExecutor:
    """
    Phase 4C local-only mutation execution path.

    The client must explicitly declare simulation_only=True. Exact
    authorization and plan validation run before the single-use lock is
    acquired. The lock is acquired before any client call. Therefore a valid
    first attempt consumes the execution right even if a later simulated
    operation fails; reruns fail closed before transport/client activity.
    """

    @staticmethod
    def _authorize(
        plan: ReleaseExecutionPlan,
        typed_authorization: str,
    ) -> None:
        if typed_authorization != plan.authorization_text():
            raise AuthorizationError("authorization text mismatch")

    @staticmethod
    def _assert_simulation_only(client: _SimulationMutationClient) -> None:
        if getattr(client, "simulation_only", False) is not True:
            raise LocalSimulationOnlyError(
                "local mutation executor requires simulation_only=True"
            )

    @staticmethod
    def _assert_plan(plan: ReleaseExecutionPlan) -> None:
        if not plan.operations:
            raise LocalMutationPlanError("operations required")

        save_count = sum(
            1 for op in plan.operations
            if op == N8nOperation.SAVE_DRAFT
        )
        publish_count = sum(
            1 for op in plan.operations
            if op == N8nOperation.PUBLISH_EXACT_VERSION
        )

        if save_count > plan.update_budget:
            raise LocalMutationPlanError("save count exceeds update budget")
        if publish_count > plan.publish_budget:
            raise LocalMutationPlanError("publish count exceeds publish budget")
        if publish_count and not plan.exact_version_id:
            raise LocalMutationPlanError("publish requires exact_version_id")

    @staticmethod
    def _acquire_execution_lock(
        *,
        plan: ReleaseExecutionPlan,
        single_use_lock_path: Path,
    ) -> None:
        if not isinstance(single_use_lock_path, Path):
            raise TypeError("single_use_lock_path must be pathlib.Path")
        acquire_single_use_lock(
            single_use_lock_path,
            {
                "stage": "LOCAL_MUTATION_SIMULATION",
                "workflowId": plan.workflow_id,
                "planSha256": plan.fingerprint_sha256(),
                "operations": [op.value for op in plan.operations],
                "updateBudget": plan.update_budget,
                "publishBudget": plan.publish_budget,
                "exactVersionId": plan.exact_version_id,
            },
        )

    def execute(
        self,
        *,
        plan: ReleaseExecutionPlan,
        typed_authorization: str,
        client: _SimulationMutationClient,
        single_use_lock_path: Path,
        draft_payload: Mapping[str, Any] | None = None,
    ) -> tuple[Mapping[str, Any], LocalMutationExecutionReceipt]:
        self._authorize(plan, typed_authorization)
        self._assert_simulation_only(client)
        self._assert_plan(plan)
        self._acquire_execution_lock(
            plan=plan,
            single_use_lock_path=single_use_lock_path,
        )

        current: Mapping[str, Any] | None = None
        mutation_count = 0

        for operation in plan.operations:
            if operation == N8nOperation.READ_WORKFLOW:
                current = client.get_workflow(plan.workflow_id)
            elif operation == N8nOperation.SAVE_DRAFT:
                if draft_payload is None:
                    raise LocalMutationPlanError(
                        "SAVE_DRAFT requires draft_payload"
                    )
                current = client.save_draft(
                    plan.workflow_id,
                    draft_payload,
                )
                mutation_count += 1
            elif operation == N8nOperation.PUBLISH_EXACT_VERSION:
                assert plan.exact_version_id is not None
                current = client.publish_exact_version(
                    plan.workflow_id,
                    plan.exact_version_id,
                )
                mutation_count += 1
            else:
                raise LocalMutationPlanError(
                    "unsupported operation=" + str(operation)
                )

        if not isinstance(current, Mapping):
            raise LocalMutationPlanError("final workflow object missing")

        receipt = LocalMutationExecutionReceipt(
            mode="LOCAL_MUTATION_SIMULATION",
            workflow_id=plan.workflow_id,
            plan_sha256=plan.fingerprint_sha256(),
            operation_count=len(plan.operations),
            mutation_operation_count=mutation_count,
            final_object_sha256=sha256_json(current),
            single_use_lock_path=str(single_use_lock_path),
        )
        return current, receipt
