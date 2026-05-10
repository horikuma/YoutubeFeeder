#!/usr/bin/env python3
"""Frontend job extraction and loading."""

from __future__ import annotations

import json
import shlex
from pathlib import Path

PACKAGE_ROOT = Path(__file__).resolve().parent
INSPECTOR_ROOT = PACKAGE_ROOT.parent
PROJECT_ROOT = INSPECTOR_ROOT.parent
DEFAULT_RAW_BUILD_LOG_PATH = PROJECT_ROOT / "llm-temp" / "xcodebuild-clean-build.log"
DEFAULT_FRONTEND_JOBS_PATH = PROJECT_ROOT / "llm-temp" / "frontend-jobs.json"
LEGACY_FRONTEND_JOBS_PATH = INSPECTOR_ROOT / "frontend-jobs.json"
MARKER = "builtin-Swift-Compilation -- "


def _extract_jobs(raw_log_path: Path) -> list[dict[str, object]]:
    lines = raw_log_path.read_text(encoding="utf-8").splitlines()
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
        raise FileNotFoundError(f"no builtin-Swift-Compilation invocation found in {raw_log_path}")

    if len(jobs) != 1:
        raise RuntimeError(f"expected exactly one builtin-Swift-Compilation invocation, found {len(jobs)}")

    return jobs


def extract_frontend_jobs(raw_log_path: Path, output_path: Path | None = None) -> list[dict[str, object]]:
    jobs = _extract_jobs(raw_log_path)
    payload = {"jobs": jobs}
    target_path = output_path or DEFAULT_FRONTEND_JOBS_PATH
    target_path.parent.mkdir(parents=True, exist_ok=True)
    target_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return jobs


def load_frontend_jobs(frontend_jobs_path: Path | None = None) -> list[dict[str, object]]:
    target_path = frontend_jobs_path or DEFAULT_FRONTEND_JOBS_PATH
    if not target_path.exists():
        if frontend_jobs_path is not None:
            raise FileNotFoundError(f"frontend-jobs.json not found: {target_path}")
        if DEFAULT_RAW_BUILD_LOG_PATH.exists():
            extract_frontend_jobs(DEFAULT_RAW_BUILD_LOG_PATH, target_path)
        elif LEGACY_FRONTEND_JOBS_PATH.exists():
            target_path = LEGACY_FRONTEND_JOBS_PATH
        else:
            raise FileNotFoundError(f"no builtin-Swift-Compilation job file found at {target_path}")

    payload = json.loads(target_path.read_text(encoding="utf-8"))
    jobs = payload.get("jobs")
    if not isinstance(jobs, list):
        raise RuntimeError("frontend-jobs.json must contain a jobs array")

    return jobs


def select_frontend_job(jobs: list[dict[str, object]], source_file: Path) -> dict[str, object]:
    if not jobs:
        raise FileNotFoundError("frontend-jobs.json contains no jobs")

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
        f"Could not select a single frontend job for {source_file}; "
        "provide a jobs.json with one job or source_files metadata"
    )
