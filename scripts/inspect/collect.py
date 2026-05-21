#!/usr/bin/env python3
"""Collect SourceKit data and write collect.db."""

from __future__ import annotations

import json
import sys
from pathlib import Path

from collect_db import CollectDbExportError, write_collect_db
from sourcekit_client import get, init
from sourcekit_client.daemon import SourceKitDaemon


def usage(error: str | None = None) -> int:
    if error:
        print(f"error: {error}", file=sys.stderr)
    print(
        "Usage: collect.py <raw-build-log> <swift-file-or-folder> <collect.db> <schema.sql> "
        "[--debug true|false] [--structure-dump <path>] [--frontend-jobs-dump <path>]",
        file=sys.stderr,
    )
    return 2 if error else 0


def dump_structure(structure: dict, structure_dump_path: Path) -> None:
    structure_dump_path.parent.mkdir(parents=True, exist_ok=True)
    structure_dump_path.write_text(
        json.dumps(structure, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )


def report_walk_status(walk_status: str, walk_count: int) -> None:
    print(f"walk {walk_status}: {walk_count} nodes", file=sys.stderr)


def _swift_paths(source_root: Path) -> list[Path]:
    if source_root.is_file():
        return [source_root]
    if source_root.is_dir():
        return sorted(path for path in source_root.rglob("*.swift") if path.is_file())
    return []


def _collect_datasets(
    raw_build_log_path: Path,
    source_root: Path,
    *,
    debug: bool,
    structure_dump_path: Path | None,
    frontend_jobs_dump_path: Path | None,
):
    datasets = []
    swift_paths = _swift_paths(source_root)
    if not swift_paths:
        raise FileNotFoundError(f"no Swift files found under: {source_root}")

    with SourceKitDaemon() as daemon:
        for source_file in swift_paths:
            print(source_file, flush=True)
            with init(
                source_file,
                raw_build_log_path,
                debug=debug,
                debug_output_path=frontend_jobs_dump_path,
                daemon=daemon,
            ) as sourcekit:
                dataset = get(sourcekit, "collect")
                if debug and structure_dump_path is not None:
                    dump_structure(dataset.structure, structure_dump_path)
                datasets.append(dataset)
                report_walk_status(dataset.walk_status, dataset.walk_count)

    return datasets


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

    structure_dump_path = None
    if "--structure-dump" in args:
        flag_index = args.index("--structure-dump")
        if flag_index + 1 >= len(args):
            return usage("expected path after --structure-dump")
        structure_dump_path = Path(args[flag_index + 1]).expanduser().resolve()
        del args[flag_index : flag_index + 2]

    frontend_jobs_dump_path = None
    if "--frontend-jobs-dump" in args:
        flag_index = args.index("--frontend-jobs-dump")
        if flag_index + 1 >= len(args):
            return usage("expected path after --frontend-jobs-dump")
        frontend_jobs_dump_path = Path(args[flag_index + 1]).expanduser().resolve()
        del args[flag_index : flag_index + 2]

    if len(args) != 4:
        return usage("expected raw build log, Swift file or folder, collect.db path, and schema path")

    raw_build_log_path = Path(args[0]).expanduser().resolve()
    source_root = Path(args[1]).expanduser().resolve()
    collect_db_path = Path(args[2]).expanduser().resolve()
    schema_path = Path(args[3]).expanduser().resolve()
    if not raw_build_log_path.exists():
        return usage(f"file not found: {raw_build_log_path}")
    if not source_root.exists():
        return usage(f"file not found: {source_root}")
    if not schema_path.exists():
        return usage(f"file not found: {schema_path}")

    try:
        datasets = _collect_datasets(
            raw_build_log_path,
            source_root,
            debug=debug,
            structure_dump_path=structure_dump_path,
            frontend_jobs_dump_path=frontend_jobs_dump_path,
        )
    except FileNotFoundError as error:
        return usage(str(error))

    try:
        write_collect_db(datasets, collect_db_path, schema_path)
    except CollectDbExportError as error:
        print(f"error: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
