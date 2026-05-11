#!/usr/bin/env python3
"""Collect SourceKit data and write collect.db."""

from __future__ import annotations

import json
import sys
from pathlib import Path

from collect_db import CollectDbExportError, write_collect_db
from sourcekit_client import get, init

PROJECT_ROOT = Path(__file__).resolve().parent.parent


def usage(error: str | None = None) -> int:
    if error:
        print(f"error: {error}", file=sys.stderr)
    print("Usage: collect.py <raw-build-log> <swift-file> [--debug true|false]", file=sys.stderr)
    print("Writes llm-cache/collect.db.", file=sys.stderr)
    return 2 if error else 0


def dump_structure(structure: dict, llm_temp_dir: Path) -> None:
    structure_dump_path = llm_temp_dir / "structure.json"
    structure_dump_path.write_text(
        json.dumps(structure, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )


def report_walk_status(walk_status: str, walk_count: int) -> None:
    print(f"walk {walk_status}: {walk_count} nodes", file=sys.stderr)


def main() -> int:
    args = sys.argv[1:]
    if len(args) == 1 and args[0] in {"-h", "--help"}:
        return usage(None)

    debug = False
    if "--debug" in args:
        flag_index = args.index("--debug")
        if flag_index + 1 >= len(args):
            return usage("expected true or false after --debug")
        debug_value = args[flag_index + 1]
        if debug_value not in {"true", "false"}:
            return usage("expected true or false after --debug")
        debug = debug_value == "true"
        del args[flag_index : flag_index + 2]

    if len(args) != 2:
        return usage("expected exactly one raw build log path and one Swift file path")

    raw_build_log_path = Path(args[0]).expanduser().resolve()
    source_file = Path(args[1]).expanduser().resolve()
    if not raw_build_log_path.exists():
        return usage(f"file not found: {raw_build_log_path}")
    if not source_file.exists():
        return usage(f"file not found: {source_file}")
    if source_file.suffix != ".swift":
        return usage(f"not a Swift file: {source_file}")

    llm_temp_dir = PROJECT_ROOT / "llm-temp"
    llm_temp_dir.mkdir(parents=True, exist_ok=True)

    with init(source_file, raw_build_log_path, debug=debug) as sourcekit:
        dataset = get(sourcekit, "collect")
        if debug:
            dump_structure(dataset.structure, llm_temp_dir)

    try:
        write_collect_db(dataset)
    except CollectDbExportError as error:
        print(f"error: {error}", file=sys.stderr)
        return 1

    report_walk_status(dataset.walk_status, dataset.walk_count)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
