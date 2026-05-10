#!/usr/bin/env python3
"""builtin-Swift-Compilation job extraction and selection."""

from __future__ import annotations

import json
import shlex
import sys
from pathlib import Path

MARKER = "builtin-Swift-Compilation -- "


def _extract_jobs(raw_build_log_path: Path) -> list[dict[str, object]]:
    lines = raw_build_log_path.read_text(encoding="utf-8").splitlines()
    jobs: list[dict[str, object]] = []

    for line_number, line in enumerate(lines, start=1):
        marker_index = line.find(MARKER)
        if marker_index < 0:
            continue

        command_text = line[marker_index + len(MARKER) :]
        argv = shlex.split(command_text, posix=True)
        jobs.append(
            {
                "kind": "builtin-Swift-Compilation",
                "raw_line": line,
                "argv": argv,
            }
        )
        print(f"match line={line_number}", file=sys.stderr)

    if not jobs:
        raise FileNotFoundError(f"no builtin-Swift-Compilation invocation found in {raw_build_log_path}")

    if len(jobs) != 1:
        raise RuntimeError(f"expected exactly one builtin-Swift-Compilation invocation, found {len(jobs)}")

    return jobs


def load_builtin_swift_compilation_jobs(
    raw_build_log_path: Path,
    *,
    debug_output_path: Path | None = None,
) -> list[dict[str, object]]:
    jobs = _extract_jobs(raw_build_log_path)
    if debug_output_path is not None:
        debug_output_path.parent.mkdir(parents=True, exist_ok=True)
        debug_output_path.write_text(
            json.dumps({"jobs": jobs}, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )
    return jobs


def select_builtin_swift_compilation_job(
    jobs: list[dict[str, object]],
    source_file: Path,
) -> dict[str, object]:
    if not jobs:
        raise FileNotFoundError("builtin-Swift-Compilation jobs are empty")

    source_file_text = str(source_file)
    matching_jobs: list[dict[str, object]] = []
    for job in jobs:
        source_files = job.get("source_files")
        if isinstance(source_files, list) and source_file_text in source_files:
            matching_jobs.append(job)

    if len(matching_jobs) == 1:
        return matching_jobs[0]

    if len(jobs) == 1:
        return jobs[0]

    raise RuntimeError(
        f"Could not select a single builtin-Swift-Compilation job for {source_file}; "
        "provide source_files metadata or reduce the input to one job"
    )
