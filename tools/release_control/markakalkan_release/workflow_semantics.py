from __future__ import annotations

from typing import Any

from .optional_field import classify_optional_field


def _representation_diff(left: Any, right: Any, path: str, out: list[str]) -> None:
    if type(left) is not type(right):
        out.append(path + ":TYPE")
        return

    if isinstance(left, dict):
        for key in sorted(set(left) | set(right)):
            here = f"{path}.{key}"
            if key not in left:
                out.append(here + ":RIGHT_ONLY")
            elif key not in right:
                out.append(here + ":LEFT_ONLY")
            else:
                _representation_diff(left[key], right[key], here, out)
        return

    if isinstance(left, list):
        if len(left) != len(right):
            out.append(path + ".length")
        for index in range(min(len(left), len(right))):
            _representation_diff(left[index], right[index], f"{path}[{index}]", out)
        return

    if left != right:
        out.append(path)


def representation_diff(left: Any, right: Any) -> list[str]:
    out: list[str] = []
    _representation_diff(left, right, "$", out)
    return out


def _node_map(workflow: dict[str, Any]) -> dict[str, dict[str, Any]]:
    nodes = workflow.get("nodes")
    if not isinstance(nodes, list):
        raise ValueError("workflow.nodes must be a list")

    result: dict[str, dict[str, Any]] = {}
    for node in nodes:
        if not isinstance(node, dict):
            raise ValueError("workflow node must be an object")
        name = node.get("name")
        if not isinstance(name, str) or not name or name in result:
            raise ValueError("workflow node names must be unique non-empty strings")
        result[name] = node
    return result


def workflow_semantic_diff(left: dict[str, Any], right: dict[str, Any]) -> list[str]:
    out: list[str] = []

    for field in ("name", "connections", "settings"):
        left_present = field in left
        right_present = field in right
        if left_present != right_present:
            out.append(f"$.{field}:PRESENCE")
        elif left_present:
            _representation_diff(left[field], right[field], f"$.{field}", out)

    left_static = classify_optional_field(left, "staticData")
    right_static = classify_optional_field(right, "staticData")
    if left_static != right_static:
        out.append("$.staticData:PRESENCE")
    elif "staticData" in left:
        _representation_diff(left["staticData"], right["staticData"], "$.staticData", out)

    left_nodes = _node_map(left)
    right_nodes = _node_map(right)

    for name in sorted(set(left_nodes) | set(right_nodes)):
        here = f"$.nodesByName[{name}]"
        if name not in left_nodes:
            out.append(here + ":RIGHT_ONLY")
        elif name not in right_nodes:
            out.append(here + ":LEFT_ONLY")
        else:
            _representation_diff(left_nodes[name], right_nodes[name], here, out)

    return out
