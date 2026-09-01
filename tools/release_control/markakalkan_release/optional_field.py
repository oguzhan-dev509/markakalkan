from __future__ import annotations

from enum import Enum
from typing import Any, Mapping


class OptionalFieldState(str, Enum):
    MISSING = "missing"
    NULL = "null"
    VALUE = "value"


def classify_optional_field(mapping: Mapping[str, Any], key: str) -> OptionalFieldState:
    if key not in mapping:
        return OptionalFieldState.MISSING
    if mapping[key] is None:
        return OptionalFieldState.NULL
    return OptionalFieldState.VALUE
