from __future__ import annotations

from dataclasses import dataclass

# =============================================================================
# INSPECTOR_BLOCK_RAW_SYMBOL_MODELS
# =============================================================================


@dataclass(frozen=True)
class RawSymbolNode:
    node: dict
    parent_node: dict | None


# =============================================================================
# INSPECTOR_BLOCK_GRAPH_MODELS
# =============================================================================


@dataclass(frozen=True)
class OwnershipResolution:
    owner_node: dict | None
    ownership_depth: int
    flatten_distance: int
    skipped_owner_count: int
    skipped_owner_reasons: tuple[str, ...]


@dataclass(frozen=True)
class SymbolGraphContext:
    parent_symbol_id: str
    parent_usr: str
    parent_kind: str
    effective_owner_symbol_id: str
    effective_owner_usr: str
    effective_owner_kind: str
    effective_owner_name: str
    ownership_depth: int
    flatten_distance: int
    skipped_owner_count: int
    skipped_owner_reasons: tuple[str, ...]


# =============================================================================
# INSPECTOR_BLOCK_NORMALIZATION_MODELS
# =============================================================================


@dataclass
class NormalizationStats:
    raw_node_count: int = 0
    normalized_symbol_count: int = 0
    deduped_symbol_count: int = 0
    skipped_symbol_count: int = 0
    usr_success_count: int = 0
    usr_failure_count: int = 0
    ownership_diverged_count: int = 0

    raw_edge_count: int = 0
    semantic_edge_count: int = 0
    flattened_edge_count: int = 0

    ownership_depth_total: int = 0
    flatten_distance_total: int = 0
    skipped_owner_total: int = 0

    max_ownership_depth: int = 0
    max_flatten_distance: int = 0

    flatten_distance_histogram: dict[int, int] | None = None

    skipped_body_count: int = 0
    skipped_main_body_count: int = 0
    skipped_previews_count: int = 0
    skipped_coding_keys_count: int = 0
    skipped_content_count: int = 0
    skipped_label_count: int = 0
    skipped_destination_count: int = 0


def normalization_skip_fields() -> dict[str, str]:
    return {
        "body": "skipped_body_count",
        "mainBody": "skipped_main_body_count",
        "previews": "skipped_previews_count",
        "CodingKeys": "skipped_coding_keys_count",
        "content": "skipped_content_count",
        "label": "skipped_label_count",
        "destination": "skipped_destination_count",
    }


def semantic_ignored_owner_names() -> set[str]:
    return set(semantic_skip_reason_by_name())


def semantic_skip_reason_by_name() -> dict[str, str]:
    return {
        "body": "swiftuiBody",
        "mainBody": "swiftuiBody",
        "previews": "swiftuiPreview",
        "CodingKeys": "synthesized",
        "content": "swiftuiBuilder",
        "label": "swiftuiBuilder",
        "destination": "swiftuiBuilder",
    }


def graph_quality_metric_names() -> tuple[str, ...]:
    return (
        "raw_node_count",
        "normalized_symbol_count",
        "deduped_symbol_count",
        "usr_failure_count",
        "ownership_diverged_count",
        "flattened_edge_count",
    )


# =============================================================================
# INSPECTOR_BLOCK_SYMBOL_MODEL
# =============================================================================


@dataclass(frozen=True)
class SymbolMetricContext:
    direct_child_count: int
    nested_depth: int
    nested_subtree_lines: int | None
    declaration_lines: int | None


@dataclass(frozen=True)
class Symbol:
    symbol_id: str
    usr: str

    parent_symbol_id: str
    parent_usr: str
    parent_kind: str

    effective_owner_symbol_id: str
    effective_owner_usr: str
    effective_owner_kind: str
    effective_owner_name: str

    file_path: str

    kind: str
    access: str

    name: str
    typename: str

    total_span_lines: int | None
    declaration_lines: int | None

    direct_child_count: int
    nested_depth: int
    nested_subtree_lines: int | None

    attributes: str
    annotated_decl: str

    is_system: bool
