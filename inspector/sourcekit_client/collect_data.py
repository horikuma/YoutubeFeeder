#!/usr/bin/env python3
"""Collect rows from SourceKit structure output."""

from __future__ import annotations

import os
import shlex
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

TARGET_FUNCTION_PREFIX = "source.lang.swift.decl.function"
TARGET_GLOBAL_KIND = "source.lang.swift.decl.var.static"
WALK_LIMIT = int(os.environ.get("COLLECT_WALK_LIMIT", "1000"))


@dataclass(frozen=True)
class FunctionRow:
    usr: str
    name: str
    file_path: Path
    line: int | None
    column: int | None
    is_definition: int


@dataclass(frozen=True)
class GlobalRow:
    usr: str
    name: str
    type: str | None
    storage_class: str | None
    file_path: Path
    line: int | None
    column: int | None
    first_seen_tu_id: int | None


@dataclass(frozen=True)
class CallEdgeRow:
    caller_usr: str
    callee_usr: str
    file_path: Path
    line: int | None
    column: int | None
    tu_id: int | None


@dataclass(frozen=True)
class CollectDataset:
    source_file: Path
    compile_directory: str | None
    compile_command: str
    structure: dict[str, Any]
    functions: list[FunctionRow] = field(default_factory=list)
    globals: list[GlobalRow] = field(default_factory=list)
    global_accesses: list[object] = field(default_factory=list)
    call_edges: list[CallEdgeRow] = field(default_factory=list)
    walk_count: int = 0
    walk_status: str = "completed"


class WalkLimitReached(Exception):
    pass


def _is_target_function(kind: object) -> bool:
    return isinstance(kind, str) and kind.startswith(TARGET_FUNCTION_PREFIX)


def _is_target_global(kind: object) -> bool:
    return kind == TARGET_GLOBAL_KIND


def _ordered_children(children: list[object]) -> list[object]:
    target_children: list[object] = []
    other_children: list[object] = []
    for child in children:
        if isinstance(child, dict) and (
            _is_target_function(child.get("key.kind")) or _is_target_global(child.get("key.kind"))
        ):
            target_children.append(child)
        else:
            other_children.append(child)
    return [*target_children, *other_children]


def _resolve_usr(sourcekit: object, offset: int) -> str | None:
    try:
        usr = sourcekit.get(offset)
    except RuntimeError:
        return None
    return usr if isinstance(usr, str) else None


def _call_usr_offset(nameoffset: int, name: str) -> int:
    dot_index = name.rfind(".")
    if dot_index < 0:
        return nameoffset
    return nameoffset + dot_index + 1


def _record_function_row(
    *,
    functions: list[FunctionRow],
    seen_function_usrs: set[str],
    usr: str,
    name: str,
    source_file: Path,
    is_definition: int,
) -> FunctionRow | None:
    if usr in seen_function_usrs:
        return None
    row = FunctionRow(
        usr=usr,
        name=name,
        file_path=source_file,
        line=None,
        column=None,
        is_definition=is_definition,
    )
    functions.append(row)
    seen_function_usrs.add(usr)
    return row


def _walk_structure(
    node: object,
    *,
    sourcekit: object,
    source_file: Path,
    walk_count: list[int],
    functions: list[FunctionRow],
    globals: list[GlobalRow],
    call_edges: list[CallEdgeRow],
    function_stack: list[FunctionRow],
    seen_function_usrs: set[str],
) -> None:
    if isinstance(node, dict):
        if getattr(sourcekit, "request_count") >= 1000:
            raise WalkLimitReached
        if walk_count[0] >= WALK_LIMIT:
            raise WalkLimitReached
        walk_count[0] += 1

        kind = node.get("key.kind")
        name = node.get("key.name")
        nameoffset = node.get("key.nameoffset")
        usr = None
        if isinstance(nameoffset, int) and (
            _is_target_function(kind) or _is_target_global(kind) or kind == "source.lang.swift.expr.call"
        ):
            if kind == "source.lang.swift.expr.call" and isinstance(name, str):
                usr = _resolve_usr(sourcekit, _call_usr_offset(nameoffset, name))
            else:
                usr = _resolve_usr(sourcekit, nameoffset)

        if isinstance(name, str) and isinstance(usr, str):
            if _is_target_function(kind):
                function_row = _record_function_row(
                    functions=functions,
                    seen_function_usrs=seen_function_usrs,
                    usr=usr,
                    name=name,
                    source_file=source_file,
                    is_definition=int(
                        isinstance(node.get("key.bodyoffset"), int) and isinstance(node.get("key.bodylength"), int)
                    ),
                )
                if function_row is not None:
                    function_stack.append(function_row)
            elif _is_target_global(kind):
                globals.append(
                    GlobalRow(
                        usr=usr,
                        name=name,
                        type=node.get("key.typename") if isinstance(node.get("key.typename"), str) else None,
                        storage_class="static",
                        file_path=source_file,
                        line=None,
                        column=None,
                        first_seen_tu_id=None,
                    )
                )
            elif kind == "source.lang.swift.expr.call" and function_stack:
                _record_function_row(
                    functions=functions,
                    seen_function_usrs=seen_function_usrs,
                    usr=usr,
                    name=name,
                    source_file=source_file,
                    is_definition=0,
                )
                call_edges.append(
                    CallEdgeRow(
                        caller_usr=function_stack[0].usr,
                        callee_usr=usr,
                        file_path=source_file,
                        line=None,
                        column=None,
                        tu_id=None,
                    )
                )

        substructure = node.get("key.substructure")
        if isinstance(substructure, list):
            for child in _ordered_children(substructure):
                _walk_structure(
                    child,
                    sourcekit=sourcekit,
                    source_file=source_file,
                    walk_count=walk_count,
                    functions=functions,
                    globals=globals,
                    call_edges=call_edges,
                    function_stack=function_stack,
                    seen_function_usrs=seen_function_usrs,
                )
        if _is_target_function(kind) and function_stack:
            function_stack.pop()
        return

    if isinstance(node, list):
        for child in _ordered_children(node):
            _walk_structure(
                child,
                sourcekit=sourcekit,
                source_file=source_file,
                walk_count=walk_count,
                functions=functions,
                globals=globals,
                call_edges=call_edges,
                function_stack=function_stack,
                seen_function_usrs=seen_function_usrs,
            )


def build_collect_dataset(sourcekit: object) -> CollectDataset:
    structure = sourcekit.get("structure")
    source_file = sourcekit.source_file
    compiler_argv = sourcekit.compiler_argv
    walk_count = [0]
    functions: list[FunctionRow] = []
    globals: list[GlobalRow] = []
    call_edges: list[CallEdgeRow] = []
    seen_function_usrs: set[str] = set()
    walk_status = "completed"

    try:
        _walk_structure(
            structure.get("key.substructure", structure),
            sourcekit=sourcekit,
            source_file=source_file,
            walk_count=walk_count,
            functions=functions,
            globals=globals,
            call_edges=call_edges,
            function_stack=[],
            seen_function_usrs=seen_function_usrs,
        )
    except WalkLimitReached:
        walk_status = "stopped_at_limit"

    return CollectDataset(
        source_file=source_file,
        compile_directory=None,
        compile_command=shlex.join(compiler_argv),
        structure=structure,
        functions=functions,
        globals=globals,
        call_edges=call_edges,
        walk_count=walk_count[0],
        walk_status=walk_status,
    )
