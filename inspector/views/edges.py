#!/usr/bin/env python3
"""Render collect.db call-edge rows through DuckDB."""

from __future__ import annotations

import argparse
import sys
from collections import defaultdict
from dataclasses import dataclass, field
from pathlib import Path
from typing import Protocol

import duckdb


@dataclass(frozen=True)
class FunctionRecord:
    usr: str
    name: str
    file_path: Path | None
    is_definition: bool


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
class SourceTargetFilter:
    source_target: Path

    def include(self, function: FunctionRecord) -> bool:
        if function.file_path is None:
            return False
        function_path = function.file_path.resolve()
        target_path = self.source_target.resolve()
        if target_path.suffix == ".swift":
            return function_path == target_path
        try:
            return function_path.is_relative_to(target_path)
        except (FileNotFoundError, ValueError):
            return False


@dataclass(frozen=True)
class DefinitionFilter:
    def include(self, function: FunctionRecord) -> bool:
        return function.is_definition


@dataclass(frozen=True)
class SwiftFileFilter:
    def include(self, function: FunctionRecord) -> bool:
        return function.file_path is not None and function.file_path.suffix == ".swift"


def usage(error: str | None = None) -> int:
    if error:
        print(f"error: {error}", file=sys.stderr)
    print("Usage: edges.py <collect.db> [--source-root <swift-file-or-folder>] [--call-graph]", file=sys.stderr)
    return 2 if error else 0


def _load_sqlite_scanner(connection: duckdb.DuckDBPyConnection) -> None:
    connection.execute("INSTALL sqlite_scanner")
    connection.execute("LOAD sqlite_scanner")


def _load_functions(db_path: Path) -> list[FunctionRecord]:
    connection = duckdb.connect(database=":memory:")
    _load_sqlite_scanner(connection)
    rows = connection.execute(
        """
        SELECT functions.usr, functions.name, files.path, functions.is_definition
        FROM sqlite_scan(?, 'functions') AS functions
        LEFT JOIN sqlite_scan(?, 'files') AS files
            ON functions.file_id = files.id
        ORDER BY files.path, functions.name, functions.usr
        """,
        [str(db_path), str(db_path)],
    ).fetchall()
    functions: list[FunctionRecord] = []
    for usr, name, file_path, is_definition in rows:
        functions.append(
            FunctionRecord(
                usr=usr,
                name=name,
                file_path=Path(file_path) if file_path else None,
                is_definition=bool(is_definition),
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


def _selected_functions(functions: list[FunctionRecord], source_target: Path | None) -> list[FunctionRecord]:
    pipeline = FunctionFilterPipeline()
    if source_target is not None:
        pipeline.add(SourceTargetFilter(source_target=source_target))
    pipeline.add(SwiftFileFilter())
    pipeline.add(DefinitionFilter())
    return pipeline.apply(functions)


def _emit_edges(db_path: Path, source_target: Path | None) -> None:
    functions = {function.usr: function for function in _selected_functions(_load_functions(db_path), source_target)}
    edges = _load_edges(db_path)
    for edge in edges:
        caller = functions.get(edge.caller_usr)
        callee = functions.get(edge.callee_usr)
        if caller is None or callee is None:
            continue
        print(f"{caller.name if caller else ''}\t{callee.name if callee else ''}\t{edge.caller_usr}\t{edge.callee_usr}")


def _function_display_name(function: FunctionRecord, source_target: Path | None) -> str:
    function_name = function.name.splitlines()[0]
    if function.file_path is None:
        return function_name
    if source_target is None:
        return f"{function_name} ({function.file_path})"
    try:
        relative_path = function.file_path.resolve().relative_to(source_target.resolve())
    except (FileNotFoundError, ValueError):
        relative_path = function.file_path
    return f"{function_name} ({relative_path})"


def _sort_key(function: FunctionRecord, source_target: Path | None) -> tuple[str, str]:
    return (_function_display_name(function, source_target).lower(), function.usr)


def _build_graph(
    functions: list[FunctionRecord],
    edges: list[EdgeRecord],
) -> tuple[dict[str, FunctionRecord], dict[str, list[str]], dict[str, list[str]]]:
    function_by_usr = {function.usr: function for function in functions}
    adjacency: dict[str, list[str]] = defaultdict(list)
    reverse_adjacency: dict[str, list[str]] = defaultdict(list)

    for edge in edges:
        if edge.caller_usr not in function_by_usr or edge.callee_usr not in function_by_usr:
            continue
        adjacency[edge.caller_usr].append(edge.callee_usr)
        reverse_adjacency[edge.callee_usr].append(edge.caller_usr)

    for callee_usrs in adjacency.values():
        callee_usrs.sort()
    for caller_usrs in reverse_adjacency.values():
        caller_usrs.sort()

    return function_by_usr, adjacency, reverse_adjacency


def _yaml_quote(value: str) -> str:
    return '"' + value.replace("\\", "\\\\").replace('"', '\\"') + '"'


def _render_call_graph(db_path: Path, source_target: Path | None) -> str:
    functions = _load_functions(db_path)
    edges = _load_edges(db_path)

    selected_functions = _selected_functions(functions, source_target)
    selected_function_by_usr = {function.usr: function for function in selected_functions}
    selected_edges = [
        edge
        for edge in edges
        if edge.caller_usr in selected_function_by_usr and edge.callee_usr in selected_function_by_usr
    ]
    function_by_usr, adjacency, reverse_adjacency = _build_graph(selected_functions, selected_edges)

    lines: list[str] = ["functions:"]
    for function in sorted(function_by_usr.values(), key=lambda item: _sort_key(item, source_target)):
        callee_usrs = sorted(
            set(adjacency.get(function.usr, [])),
            key=lambda usr: _sort_key(function_by_usr[usr], source_target),
        )
        caller_usrs = sorted(
            set(reverse_adjacency.get(function.usr, [])),
            key=lambda usr: _sort_key(function_by_usr[usr], source_target),
        )
        lines.append(f"  - name: {_yaml_quote(function.name.splitlines()[0])}")
        if callee_usrs:
            lines.append("    calls:")
            for callee_usr in callee_usrs:
                callee = function_by_usr[callee_usr]
                lines.append(f"      - {_yaml_quote(callee.name.splitlines()[0])}")
        if caller_usrs:
            lines.append("    called_by:")
            for caller_usr in caller_usrs:
                caller = function_by_usr[caller_usr]
                lines.append(f"      - {_yaml_quote(caller.name.splitlines()[0])}")

    return "\n".join(lines) + "\n"


def _parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(add_help=True, prog="edges.py")
    parser.add_argument("collect_db", help="collect.db path")
    parser.add_argument("--source-root", dest="source_root", help="Swift file or root folder for declarations")
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
            source_root = Path(args.source_root).expanduser().resolve() if args.source_root else None
            _emit_edges(db_path, source_root)
    except Exception as error:
        print(f"error: {error}", file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
