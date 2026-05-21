#!/usr/bin/env python3
"""Collect rows from SourceKit structure output."""

from __future__ import annotations

import shlex
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

TARGET_FUNCTION_PREFIX = "source.lang.swift.decl.function"
TARGET_GLOBAL_KIND = "source.lang.swift.decl.var.static"
TARGET_TYPE_KINDS = {
    "source.lang.swift.decl.actor",
    "source.lang.swift.decl.class",
    "source.lang.swift.decl.enum",
    "source.lang.swift.decl.extension",
    "source.lang.swift.decl.struct",
}


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
    argument_summary: str | None
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


def _is_target_type(kind: object) -> bool:
    return kind in TARGET_TYPE_KINDS


def _qualified_function_name(name: str, type_stack: list[str]) -> str:
    if not type_stack:
        return name
    return ".".join([*type_stack, name])


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


def _byte_offset_to_text_index(source_text: str, byte_offset: int) -> int:
    return len(source_text.encode("utf-8")[:byte_offset].decode("utf-8", errors="ignore"))


def _byte_range_text(source_text: str, byte_offset: int, byte_length: int) -> str:
    start_index = _byte_offset_to_text_index(source_text, byte_offset)
    end_index = _byte_offset_to_text_index(source_text, byte_offset + byte_length)
    return source_text[start_index:end_index]


def _split_top_level(value: str, separator: str) -> list[str]:
    parts: list[str] = []
    start = 0
    depth = 0
    quote: str | None = None
    escaped = False

    for index, character in enumerate(value):
        if quote is not None:
            if escaped:
                escaped = False
            elif character == "\\":
                escaped = True
            elif character == quote:
                quote = None
            continue

        if character in {'"', "'"}:
            quote = character
        elif character in "([{":
            depth += 1
        elif character in ")]}":
            depth = max(0, depth - 1)
        elif character == separator and depth == 0:
            parts.append(value[start:index].strip())
            start = index + 1

    tail = value[start:].strip()
    if tail:
        parts.append(tail)
    return parts


def _top_level_separator_index(value: str, separator: str) -> int | None:
    depth = 0
    quote: str | None = None
    escaped = False

    for index, character in enumerate(value):
        if quote is not None:
            if escaped:
                escaped = False
            elif character == "\\":
                escaped = True
            elif character == quote:
                quote = None
            continue

        if character in {'"', "'"}:
            quote = character
        elif character in "([{":
            depth += 1
        elif character in ")]}":
            depth = max(0, depth - 1)
        elif character == separator and depth == 0:
            return index
    return None


def _matching_close_paren(source_text: str, open_index: int) -> int | None:
    depth = 0
    quote: str | None = None
    escaped = False

    for index in range(open_index, len(source_text)):
        character = source_text[index]
        if quote is not None:
            if escaped:
                escaped = False
            elif character == "\\":
                escaped = True
            elif character == quote:
                quote = None
            continue

        if character in {'"', "'"}:
            quote = character
        elif character == "(":
            depth += 1
        elif character == ")":
            depth -= 1
            if depth == 0:
                return index
    return None


def _argument_labels(call_name: str) -> list[str]:
    open_index = call_name.find("(")
    close_index = call_name.rfind(")")
    if open_index < 0 or close_index < open_index:
        return []

    signature = call_name[open_index + 1 : close_index]
    labels: list[str] = []
    for part in signature.split(":"):
        label = part.split()[-1] if part.split() else ""
        if label:
            labels.append(label)
    return labels


def _argument_summary_from_structure(source_text: str, node: dict[object, object]) -> str | None:
    children = node.get("key.substructure")
    if not isinstance(children, list):
        return None

    entries: list[str] = []
    argument_index = 1
    for child in children:
        if not isinstance(child, dict) or child.get("key.kind") != "source.lang.swift.expr.argument":
            continue

        label = child.get("key.name")
        if not isinstance(label, str) or not label:
            label = f"arg{argument_index}"
        argument_index += 1

        bodyoffset = child.get("key.bodyoffset")
        bodylength = child.get("key.bodylength")
        if not isinstance(bodyoffset, int) or not isinstance(bodylength, int):
            continue

        expression = _byte_range_text(source_text, bodyoffset, bodylength).strip()
        if expression:
            entries.append(f"{label} <- {expression}")

    return "; ".join(entries) if entries else None


def _argument_summary(source_text: str, nameoffset: int, call_name: str, node: dict[object, object]) -> str | None:
    structured_summary = _argument_summary_from_structure(source_text, node)
    if structured_summary is not None:
        return structured_summary

    if "(" not in call_name:
        return None

    call_offset = _call_usr_offset(nameoffset, call_name)
    start_index = _byte_offset_to_text_index(source_text, call_offset)
    base_name = call_name.rsplit(".", maxsplit=1)[-1].split("(", maxsplit=1)[0]
    open_index = source_text.find("(", start_index + len(base_name))
    if open_index < 0:
        return None

    close_index = _matching_close_paren(source_text, open_index)
    if close_index is None:
        return None

    argument_text = source_text[open_index + 1 : close_index].strip()
    if not argument_text:
        return None

    labels = _argument_labels(call_name)
    entries: list[str] = []
    for index, argument in enumerate(_split_top_level(argument_text, ",")):
        colon_index = _top_level_separator_index(argument, ":")
        if colon_index is None:
            label = labels[index] if index < len(labels) else f"arg{index + 1}"
            expression = argument.strip()
        else:
            label = argument[:colon_index].strip()
            expression = argument[colon_index + 1 :].strip()

        if not label or label == "_":
            label = f"arg{index + 1}"
        if expression:
            entries.append(f"{label} <- {expression}")

    return "; ".join(entries) if entries else None


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
        if is_definition == 1:
            row = FunctionRow(
                usr=usr,
                name=name,
                file_path=source_file,
                line=None,
                column=None,
                is_definition=is_definition,
            )
            for index, existing_row in enumerate(functions):
                if existing_row.usr == usr and existing_row.is_definition == 0:
                    functions[index] = row
                    return row
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
    type_stack: list[str],
    seen_function_usrs: set[str],
    source_text: str,
) -> None:
    if isinstance(node, dict):
        walk_count[0] += 1

        kind = node.get("key.kind")
        name = node.get("key.name")
        nameoffset = node.get("key.nameoffset")
        pushed_type = False
        if _is_target_type(kind) and isinstance(name, str):
            type_stack.append(name)
            pushed_type = True

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
                    name=_qualified_function_name(name, type_stack),
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
                        argument_summary=_argument_summary(source_text, nameoffset, name, node),
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
                    type_stack=type_stack,
                    seen_function_usrs=seen_function_usrs,
                    source_text=source_text,
                )
        if _is_target_function(kind) and function_stack:
            function_stack.pop()
        if pushed_type:
            type_stack.pop()
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
                type_stack=type_stack,
                seen_function_usrs=seen_function_usrs,
                source_text=source_text,
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
    source_text = source_file.read_text(encoding="utf-8")

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
            type_stack=[],
            seen_function_usrs=seen_function_usrs,
            source_text=source_text,
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
