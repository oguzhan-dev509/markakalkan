from __future__ import annotations

from enum import Enum


class ReleaseState(str, Enum):
    LOCKED = "LOCKED"
    PRECHECKED = "PRECHECKED"
    DRAFT_CREATED = "DRAFT_CREATED"
    DRAFT_VERIFIED = "DRAFT_VERIFIED"
    PUBLISHED = "PUBLISHED"
    POST_VERIFIED = "POST_VERIFIED"
    CLOSED = "CLOSED"


class TransitionError(ValueError):
    pass


_ALLOWED = {
    ReleaseState.LOCKED: frozenset({ReleaseState.PRECHECKED}),
    ReleaseState.PRECHECKED: frozenset({
        ReleaseState.DRAFT_CREATED,
        ReleaseState.DRAFT_VERIFIED,
    }),
    ReleaseState.DRAFT_CREATED: frozenset({ReleaseState.DRAFT_VERIFIED}),
    ReleaseState.DRAFT_VERIFIED: frozenset({ReleaseState.PUBLISHED}),
    ReleaseState.PUBLISHED: frozenset({ReleaseState.POST_VERIFIED}),
    ReleaseState.POST_VERIFIED: frozenset({ReleaseState.CLOSED}),
    ReleaseState.CLOSED: frozenset(),
}


def ensure_transition(current: ReleaseState, target: ReleaseState) -> None:
    if target not in _ALLOWED[current]:
        raise TransitionError(f"illegal release transition: {current.value} -> {target.value}")
