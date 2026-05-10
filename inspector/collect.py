#!/usr/bin/env python3
"""Collect Swift function nodes and resolve USRs."""

from __future__ import annotations

import json
import os
import sys
from dataclasses import dataclass
from pathlib import Path

from sourcekit_client import (
    find_sourcekit_lsp,
    find_sourcekitd,
    load_frontend_jobs,
    load_structure,
    query_usr,
    select_frontend_job,
)

ROOT = Path(__file__).resolve().parent
PROJECT_ROOT = ROOT.parent

TARGET_KIND_PREFIXES = ("source.lang.swift.decl.function",)

WALK_LIMIT = int(os.environ.get("COLLECT_WALK_LIMIT", "100"))


def usage(error: str | None = None) -> int:
    if error:
        print(f"error: {error}", file=sys.stderr)
    print("Usage: collect.py <swift-file>", file=sys.stderr)
    print("Consumes llm-temp/frontend-jobs.json only.", file=sys.stderr)
    return 2 if error else 0


@dataclass(frozen=True)
class FunctionEntry:
    name: str
    usr: str


class WalkLimitReached(Exception):
    pass


def is_target_kind(kind: object) -> bool:
    if not isinstance(kind, str):
        return False
    return any(kind.startswith(prefix) for prefix in TARGET_KIND_PREFIXES)


def ordered_children(children: list[object]) -> list[object]:
    target_children: list[object] = []
    other_children: list[object] = []
    for child in children:
        if isinstance(child, dict) and is_target_kind(child.get("key.kind")):
            target_children.append(child)
        else:
            other_children.append(child)
    return [*target_children, *other_children]


def collect_caller_callee(
    node: object,
    source_file: Path,
    *,
    compiler_argv: list[str],
    sourcekit_lsp_cmd: list[str],
    sourcekitd: Path,
    usr_cache: dict[int, str | None],
    walk_count: list[int],
    entries: list[FunctionEntry],
) -> None:
    deferred: list[object] = []

    def visit(current: object) -> None:
        if isinstance(current, dict):
            if walk_count[0] >= WALK_LIMIT:
                raise WalkLimitReached
            walk_count[0] += 1
            kind = current.get("key.kind")
            offset = current.get("key.nameoffset")
            name = current.get("key.name")
            if is_target_kind(kind) and isinstance(offset, int):
                if offset not in usr_cache:
                    usr_cache[offset] = query_usr(
                        source_file,
                        offset,
                        compiler_argv=compiler_argv,
                        sourcekit_lsp_cmd=sourcekit_lsp_cmd,
                        sourcekitd=sourcekitd,
                    )
                usr = usr_cache[offset]
                if isinstance(name, str) and usr:
                    entries.append(FunctionEntry(name=name, usr=usr))

            substructure = current.get("key.substructure")
            if isinstance(substructure, list):
                deferred.append(substructure)
            return

        if isinstance(current, list):
            for child in ordered_children(current):
                if isinstance(child, dict):
                    visit(child)
                elif isinstance(child, list):
                    deferred.append(child)

    visit(node)
    for child in deferred:
        collect_caller_callee(
            child,
            source_file,
            compiler_argv=compiler_argv,
            sourcekit_lsp_cmd=sourcekit_lsp_cmd,
            sourcekitd=sourcekitd,
            usr_cache=usr_cache,
            walk_count=walk_count,
            entries=entries,
        )


def build_graph(entries: list[FunctionEntry]) -> list[FunctionEntry]:
    return entries


def filtering(entries: list[FunctionEntry]) -> list[FunctionEntry]:
    return [entry for entry in entries if entry.name and entry.usr]


def dump_structure(structure: dict, llm_temp_dir: Path) -> None:
    structure_dump_path = llm_temp_dir / "structure.json"
    structure_dump_path.write_text(
        json.dumps(structure, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )


def report_walk_status(walk_status: str, walk_count: int) -> None:
    if walk_status == "stopped_at_limit":
        print(f"walk stopped at limit {WALK_LIMIT}: {walk_count} nodes", file=sys.stderr)
    else:
        print(f"walk completed: {walk_count} nodes", file=sys.stderr)


def emit_graph(entries: list[FunctionEntry]) -> None:
    for entry in entries:
        print(f"{entry.name}\t{entry.usr}")


def main() -> int:
    if len(sys.argv) != 2 or sys.argv[1] in {"-h", "--help"}:
        return usage(
            None if len(sys.argv) == 2 and sys.argv[1] in {"-h", "--help"} else "expected exactly one Swift file path"
        )

    source_file = Path(sys.argv[1]).expanduser().resolve()
    if not source_file.exists():
        return usage(f"file not found: {source_file}")
    if source_file.suffix != ".swift":
        return usage(f"not a Swift file: {source_file}")

    structure = load_structure(source_file)

    llm_temp_dir = PROJECT_ROOT / "llm-temp"
    llm_temp_dir.mkdir(parents=True, exist_ok=True)
    dump_structure(structure, llm_temp_dir)

    jobs = load_frontend_jobs()
    job = select_frontend_job(jobs, source_file)

    compiler_argv = job.get("argv")
    if (
        not isinstance(compiler_argv, list)
        or not compiler_argv
        or not all(isinstance(item, str) for item in compiler_argv)
    ):
        raise RuntimeError("frontend job argv must be a non-empty list of strings")

    sourcekitd = find_sourcekitd()
    sourcekit_lsp_cmd = find_sourcekit_lsp()

    usr_cache: dict[int, str | None] = {}
    walk_count = [0]
    walk_status = "completed"
    caller_callee_entries: list[FunctionEntry] = []
    try:
        collect_caller_callee(
            structure.get("key.substructure", structure),
            source_file,
            compiler_argv=compiler_argv,
            sourcekit_lsp_cmd=sourcekit_lsp_cmd,
            sourcekitd=sourcekitd,
            usr_cache=usr_cache,
            walk_count=walk_count,
            entries=caller_callee_entries,
        )
    except WalkLimitReached:
        walk_status = "stopped_at_limit"

    graph = build_graph(caller_callee_entries)
    filtered_graph = filtering(graph)
    report_walk_status(walk_status, walk_count[0])
    emit_graph(filtered_graph)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
