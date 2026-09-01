from __future__ import annotations
from dataclasses import dataclass
from enum import Enum
import re
from typing import Any, Mapping, Protocol, Sequence
from .safety import MutationBudget, MutationKind

_SAFE_ID = re.compile(r"^[A-Za-z0-9._-]+$")

class ScopeError(PermissionError): pass
class ResponseContractError(ValueError): pass

class N8nOperation(str, Enum):
    READ_WORKFLOW = "READ_WORKFLOW"
    SAVE_DRAFT = "SAVE_DRAFT"
    PUBLISH_EXACT_VERSION = "PUBLISH_EXACT_VERSION"

REQUIRED_SCOPE = {
    N8nOperation.READ_WORKFLOW: "workflow:read",
    N8nOperation.SAVE_DRAFT: "workflow:update",
    N8nOperation.PUBLISH_EXACT_VERSION: "workflow:activate",
}

class N8nTransport(Protocol):
    def request(self, method: str, path: str, body: Mapping[str, Any] | None = None) -> Mapping[str, Any]: ...

def _safe_id(value: str, label: str) -> str:
    if not isinstance(value, str) or not value or not _SAFE_ID.fullmatch(value):
        raise ValueError(f"invalid {label}")
    return value

class N8nWorkflowClient:
    def __init__(self, *, transport: N8nTransport, declared_scopes: Sequence[str], mutation_budget: MutationBudget):
        self._transport = transport
        self._scopes = frozenset(declared_scopes)
        self._budget = mutation_budget

    def _require_scope(self, operation: N8nOperation) -> None:
        required = REQUIRED_SCOPE[operation]
        if required not in self._scopes:
            raise ScopeError(f"{operation.value} requires declared scope {required}")

    @staticmethod
    def _require_mapping(value: Mapping[str, Any]) -> Mapping[str, Any]:
        if not isinstance(value, Mapping):
            raise ResponseContractError("n8n response must be an object")
        return value

    def get_workflow(self, workflow_id: str) -> Mapping[str, Any]:
        self._require_scope(N8nOperation.READ_WORKFLOW)
        wid = _safe_id(workflow_id, "workflow_id")
        return self._require_mapping(self._transport.request("GET", f"/api/v1/workflows/{wid}", None))

    def save_draft(self, workflow_id: str, payload: Mapping[str, Any]) -> Mapping[str, Any]:
        self._require_scope(N8nOperation.SAVE_DRAFT)
        wid = _safe_id(workflow_id, "workflow_id")
        if not isinstance(payload, Mapping):
            raise ValueError("payload must be an object")
        self._budget.consume(MutationKind.UPDATE_DRAFT)
        return self._require_mapping(
            self._transport.request("PUT", f"/api/v1/workflows/{wid}?publishIfActive=false", payload)
        )

    def publish_exact_version(self, workflow_id: str, version_id: str) -> Mapping[str, Any]:
        self._require_scope(N8nOperation.PUBLISH_EXACT_VERSION)
        wid = _safe_id(workflow_id, "workflow_id")
        vid = _safe_id(version_id, "version_id")
        self._budget.consume(MutationKind.PUBLISH)
        return self._require_mapping(
            self._transport.request("POST", f"/api/v1/workflows/{wid}/publish", {"versionId": vid})
        )
