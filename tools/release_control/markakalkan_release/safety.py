from __future__ import annotations
from dataclasses import dataclass, field
from enum import Enum
import json
from pathlib import Path
from typing import Any, Mapping

class MutationKind(str, Enum):
    UPDATE_DRAFT = "UPDATE_DRAFT"
    PUBLISH = "PUBLISH"

class MutationBudgetExceeded(RuntimeError): pass
class SingleUseLockExists(RuntimeError): pass

@dataclass
class MutationBudget:
    limits: Mapping[MutationKind, int]
    _used: dict[MutationKind, int] = field(default_factory=dict, init=False)

    def __post_init__(self) -> None:
        normalized = {}
        for kind in MutationKind:
            value = self.limits.get(kind, 0)
            if not isinstance(value, int) or isinstance(value, bool) or value < 0:
                raise ValueError(f"invalid mutation limit for {kind.value}")
            normalized[kind] = value
        self.limits = normalized

    def consume(self, kind: MutationKind) -> None:
        used = self._used.get(kind, 0)
        limit = self.limits[kind]
        if used >= limit:
            raise MutationBudgetExceeded(f"{kind.value} mutation budget exhausted: {used}/{limit}")
        self._used[kind] = used + 1

    def used(self, kind: MutationKind) -> int:
        return self._used.get(kind, 0)

    def remaining(self, kind: MutationKind) -> int:
        return self.limits[kind] - self.used(kind)

    def snapshot(self) -> dict[str, dict[str, int]]:
        return {
            kind.value: {"limit": self.limits[kind], "used": self.used(kind), "remaining": self.remaining(kind)}
            for kind in MutationKind
        }

def acquire_single_use_lock(path: Path, metadata: Mapping[str, Any]) -> None:
    if not isinstance(metadata, Mapping):
        raise ValueError("metadata must be an object")
    payload = dict(metadata)
    payload["rerunAllowed"] = False
    path.parent.mkdir(parents=True, exist_ok=True)
    try:
        with path.open("x", encoding="utf-8", newline="\n") as stream:
            json.dump(payload, stream, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
            stream.write("\n")
    except FileExistsError as error:
        raise SingleUseLockExists(str(path)) from error
