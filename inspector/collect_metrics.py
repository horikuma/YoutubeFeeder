# ruff: fix
from __future__ import annotations

from collect_models import (
    SymbolMetricContext,
    semantic_ignored_owner_names,
)


def ignored_metric_property_names() -> set[str]:
    return {
        "wrappedValue",
        "projectedValue",
    }


def semantic_metric_children(
    node: dict,
) -> list[dict]:
    return [child for child in node.get("key.substructure", []) if not should_ignore_metric_child(child)]


def semantic_metric_child_count(node: dict) -> int:
    return len(semantic_metric_children(node))


# =============================================================================
# INSPECTOR_BLOCK_METRIC_CONTEXT
# =============================================================================


def should_ignore_metric_child(node: dict) -> bool:
    name = node.get("key.name", "")

    return name in semantic_ignored_owner_names() or name in ignored_metric_property_names()


def build_symbol_metric_context(
    node: dict,
    file_content: str,
) -> SymbolMetricContext:
    offset = node.get("key.offset")
    body_offset = node.get("key.bodyoffset")

    nested_subtree_lines = calculate_subtree_line_count(
        node,
        file_content,
    )

    declaration_lines = calculate_declaration_lines(
        file_content,
        offset,
        body_offset,
    )

    return SymbolMetricContext(
        direct_child_count=semantic_metric_child_count(node),
        nested_depth=calculate_nested_depth(node),
        nested_subtree_lines=nested_subtree_lines,
        declaration_lines=declaration_lines,
    )


# =============================================================================
# INSPECTOR_BLOCK_LINE_METRICS
# =============================================================================


def calculate_line_count(
    content: str,
    offset: int | None,
    length: int | None,
) -> int | None:
    if offset is None or length is None:
        return None

    fragment = content[offset : offset + length]

    return fragment.count("\n") + 1


def calculate_declaration_lines(
    content: str,
    offset: int | None,
    body_offset: int | None,
) -> int | None:
    if offset is None:
        return None

    if body_offset is None:
        return None

    if body_offset <= offset:
        return None

    fragment = content[offset:body_offset]

    return fragment.count("\n") + 1


# =============================================================================
# INSPECTOR_BLOCK_SUBTREE_METRICS
# =============================================================================


def calculate_nested_child_lines(
    node: dict,
    file_content: str,
) -> int:
    total = 0

    for child in semantic_metric_children(node):
        child_line_count = calculate_subtree_line_count(
            child,
            file_content,
        )

        if child_line_count is not None:
            total += child_line_count

    return total


def calculate_subtree_line_count(
    node: dict,
    file_content: str,
) -> int | None:
    offset = node.get("key.offset")
    length = node.get("key.length")

    total_span_lines = calculate_line_count(
        file_content,
        offset,
        length,
    )

    if total_span_lines is None:
        return None

    nested_child_lines = calculate_nested_child_lines(
        node,
        file_content,
    )

    declaration_lines = max(
        1,
        total_span_lines - nested_child_lines,
    )

    return declaration_lines + nested_child_lines


# =============================================================================
# INSPECTOR_BLOCK_DEPTH_METRICS
# =============================================================================


def calculate_nested_depth(node: dict) -> int:
    children = semantic_metric_children(node)

    if not children:
        return 0

    return 1 + max(calculate_nested_depth(child) for child in children)
