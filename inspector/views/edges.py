#!/usr/bin/env python3
"""Render collect.db call-edge rows through DuckDB."""

from __future__ import annotations

import argparse
from collections import defaultdict
from dataclasses import dataclass, field
import sys
from pathlib import Path
from typing import Protocol

import duckdb


@dataclass(frozen=True)
class FunctionRecord:
    usr: str
    name: str
    file_path: Path | None


@dataclass(frozen=True)
class EdgeRecord:
    caller_usr: str
    callee_usr: str


class FunctionFilter(Protocol):
    def include(self, function: FunctionRecord) -> bool: ...


@dataclass
class FunctionFilterPipeline:
    filters: list[FunctionFilter] = field(default_factory=list)

    def add(self, function_filter: FunctionFilter) -> None:
        self.filters.append(function_filter)

    def apply(self, functions: list[FunctionRecord]) -> list[FunctionRecord]:
        selected = functions
        for function_filter in self.filters:
            selected = [function for function in selected if function_filter.include(function)]
        return selected


@dataclass(frozen=True)
class SourceRootFilter:
    source_root: Path

    def include(self, function: FunctionRecord) -> bool:
        if function.file_path is None:
            return False
        try:
            return function.file_path.resolve().is_relative_to(self.source_root.resolve())
        except (FileNotFoundError, ValueError):
            return False


@dataclass(frozen=True)
class SwiftFileFilter:
    def include(self, function: FunctionRecord) -> bool:
        return function.file_path is not None and function.file_path.suffix == ".swift"


def usage(error: str | None = None) -> int:
    if error:
        print(f"error: {error}", file=sys.stderr)
    print("Usage: edges.py <collect.db> [--source-root <path>] [--call-graph]", file=sys.stderr)
    return 2 if error else 0


def _load_sqlite_scanner(connection: duckdb.DuckDBPyConnection) -> None:
    connection.execute("INSTALL sqlite_scanner")
    connection.execute("LOAD sqlite_scanner")


def _load_functions(db_path: Path) -> list[FunctionRecord]:
    connection = duckdb.connect(database=":memory:")
    _load_sqlite_scanner(connection)
    rows = connection.execute(
        """
        SELECT functions.usr, functions.name, files.path
        FROM sqlite_scan(?, 'functions') AS functions
        LEFT JOIN sqlite_scan(?, 'files') AS files
            ON functions.file_id = files.id
        ORDER BY files.path, functions.name, functions.usr
        """,
        [str(db_path), str(db_path)],
    ).fetchall()
    functions: list[FunctionRecord] = []
    for usr, name, file_path in rows:
        functions.append(
            FunctionRecord(
                usr=usr,
                name=name,
                file_path=Path(file_path) if file_path else None,
            )
        )
    return functions


def _load_edges(db_path: Path) -> list[EdgeRecord]:
    connection = duckdb.connect(database=":memory:")
    _load_sqlite_scanner(connection)
    rows = connection.execute(
        """
        SELECT caller_usr, callee_usr
        FROM sqlite_scan(?, 'call_edges')
        ORDER BY caller_usr, callee_usr, id
        """,
        [str(db_path)],
    ).fetchall()
    return [EdgeRecord(caller_usr=caller_usr, callee_usr=callee_usr) for caller_usr, callee_usr in rows]


def _emit_edges(db_path: Path) -> None:
    functions = {function.usr: function for function in _load_functions(db_path)}
    edges = _load_edges(db_path)
    for edge in edges:
        caller = functions.get(edge.caller_usr)
        callee = functions.get(edge.callee_usr)
        print(f"{caller.name if caller else ''}\t{callee.name if callee else ''}\t{edge.caller_usr}\t{edge.callee_usr}")


def _function_display_name(function: FunctionRecord, source_root: Path | None) -> str:
    function_name = function.name.splitlines()[0]
    if function.file_path is None:
        return function_name
    if source_root is None:
        return f"{function_name} ({function.file_path})"
    try:
        relative_path = function.file_path.resolve().relative_to(source_root.resolve())
    except (FileNotFoundError, ValueError):
        relative_path = function.file_path
    return f"{function_name} ({relative_path})"


def _escape_mermaid_label(text: str) -> str:
    normalized = " ".join(text.split())
    return normalized.replace("\\", "\\\\").replace('"', '\\"')


def _sort_key(function: FunctionRecord, source_root: Path | None) -> tuple[str, str]:
    return (_function_display_name(function, source_root).lower(), function.usr)


def _build_graph(functions: list[FunctionRecord], edges: list[EdgeRecord]) -> tuple[dict[str, FunctionRecord], dict[str, list[str]], dict[str, int]]:
    function_by_usr = {function.usr: function for function in functions}
    adjacency: dict[str, list[str]] = defaultdict(list)
    incoming_counts: dict[str, int] = defaultdict(int)

    for edge in edges:
        if edge.caller_usr not in function_by_usr or edge.callee_usr not in function_by_usr:
            continue
        adjacency[edge.caller_usr].append(edge.callee_usr)
        incoming_counts[edge.callee_usr] += 1

    for callee_usrs in adjacency.values():
        callee_usrs.sort()

    return function_by_usr, adjacency, incoming_counts


def _collect_reachable(root_usr: str, adjacency: dict[str, list[str]]) -> tuple[list[str], list[tuple[str, str]]]:
    visited: set[str] = set()
    reachable_usrs: list[str] = []
    reachable_edges: list[tuple[str, str]] = []

    def visit(usr: str) -> None:
        if usr in visited:
            return
        visited.add(usr)
        reachable_usrs.append(usr)
        for callee_usr in adjacency.get(usr, []):
            reachable_edges.append((usr, callee_usr))
            visit(callee_usr)

    visit(root_usr)
    return reachable_usrs, reachable_edges


def _render_call_graph(db_path: Path, source_root: Path | None) -> str:
    functions = _load_functions(db_path)
    edges = _load_edges(db_path)

    pipeline = FunctionFilterPipeline()
    if source_root is not None:
        pipeline.add(SourceRootFilter(source_root=source_root))
    pipeline.add(SwiftFileFilter())

    selected_functions = pipeline.apply(functions)
    selected_function_by_usr = {function.usr: function for function in selected_functions}
    selected_edges = [
        edge
        for edge in edges
        if edge.caller_usr in selected_function_by_usr and edge.callee_usr in selected_function_by_usr
    ]
    function_by_usr, adjacency, incoming_counts = _build_graph(selected_functions, selected_edges)

    roots = [
        function
        for function in selected_functions
        if incoming_counts.get(function.usr, 0) == 0
    ]
    roots.sort(key=lambda function: _sort_key(function, source_root))

    lines: list[str] = ["# Call Graph"]
    if not roots:
        lines.extend(["", "No root functions found."])
        return "\n".join(lines) + "\n"

    for index, root in enumerate(roots, start=1):
        if index > 1:
            lines.append("")
        root_label = _function_display_name(root, source_root)
        lines.extend(
            [
                f"## Root {index}: {root_label}",
                "```mermaid",
                "flowchart TD",
            ]
        )

        reachable_usrs, reachable_edges = _collect_reachable(root.usr, adjacency)
        reachable_set = set(reachable_usrs)
        node_ids = {usr: f"n{node_index}" for node_index, usr in enumerate(reachable_usrs)}

        for usr in reachable_usrs:
            function = function_by_usr[usr]
            label = _escape_mermaid_label(_function_display_name(function, source_root))
            lines.append(f'    {node_ids[usr]}["{label}"]')

        rendered_edges: set[tuple[str, str]] = set()
        for caller_usr, callee_usr in reachable_edges:
            if caller_usr not in reachable_set or callee_usr not in reachable_set:
                continue
            edge_key = (caller_usr, callee_usr)
            if edge_key in rendered_edges:
                continue
            rendered_edges.add(edge_key)
            lines.append(f"    {node_ids[caller_usr]} --> {node_ids[callee_usr]}")

        lines.append("```")

    return "\n".join(lines) + "\n"


def _parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(add_help=True, prog="edges.py")
    parser.add_argument("collect_db", help="collect.db path")
    parser.add_argument("--source-root", dest="source_root", help="root folder for Swift declarations")
    parser.add_argument("--call-graph", action="store_true", help="render Mermaid call graphs instead of raw edges")
    return parser.parse_args()


def main() -> int:
    try:
        args = _parse_args()
    except SystemExit as error:
        return int(error.code) if isinstance(error.code, int) else 1

    db_path = Path(args.collect_db).expanduser().resolve()
    if not db_path.exists():
        return usage(f"file not found: {db_path}")

    try:
        if args.call_graph:
            source_root = Path(args.source_root).expanduser().resolve() if args.source_root else None
            sys.stdout.write(_render_call_graph(db_path, source_root))
        else:
            _emit_edges(db_path)
    except Exception as error:
        print(f"error: {error}", file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
