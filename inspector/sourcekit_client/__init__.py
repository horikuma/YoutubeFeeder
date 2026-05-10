#!/usr/bin/env python3
"""SourceKit client helpers."""

from __future__ import annotations

import json
import subprocess
from dataclasses import dataclass, field
from pathlib import Path

from .daemon import SourceKitDaemon

PACKAGE_ROOT = Path(__file__).resolve().parent
INSPECTOR_ROOT = PACKAGE_ROOT.parent
FRONTEND_JOBS_PATH = INSPECTOR_ROOT / "frontend-jobs.json"

__all__ = ["init", "get"]


def _run_command(args: list[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(args, check=True, text=True, capture_output=True)


def _load_structure(file_path: Path) -> dict:
    result = _run_command(["sourcekitten", "structure", "--file", str(file_path)])
    return json.loads(result.stdout)


def _load_frontend_jobs() -> list[dict[str, object]]:
    if not FRONTEND_JOBS_PATH.exists():
        raise FileNotFoundError(f"frontend-jobs.json not found: {FRONTEND_JOBS_PATH}")

    payload = json.loads(FRONTEND_JOBS_PATH.read_text(encoding="utf-8"))
    jobs = payload.get("jobs")
    if not isinstance(jobs, list):
        raise RuntimeError("frontend-jobs.json must contain a jobs array")

    return jobs


def _select_frontend_job(jobs: list[dict[str, object]], source_file: Path) -> dict[str, object]:
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


@dataclass
class _SourceKitClient:
    source_file: Path
    compiler_argv: list[str]
    structure: dict
    daemon: SourceKitDaemon
    usr_cache: dict[int, str | None] = field(default_factory=dict)

    def __enter__(self) -> "_SourceKitClient":
        return self

    def __exit__(self, exc_type, exc, tb) -> None:
        self.close()

    @property
    def request_count(self) -> int:
        return self.daemon.request_count

    def close(self) -> None:
        self.daemon.close()

    def get(self, key: int | str) -> object:
        if key == "structure":
            return self.structure
        if isinstance(key, int):
            if key not in self.usr_cache:
                self.usr_cache[key] = self.daemon.query_usr(
                    self.source_file,
                    key,
                    compiler_argv=self.compiler_argv,
                )
            return self.usr_cache[key]
        raise TypeError(f"unsupported key: {key!r}")


def init(source_file: Path) -> _SourceKitClient:
    structure = _load_structure(source_file)
    jobs = _load_frontend_jobs()
    job = _select_frontend_job(jobs, source_file)

    compiler_argv = job.get("argv")
    if (
        not isinstance(compiler_argv, list)
        or not compiler_argv
        or not all(isinstance(item, str) for item in compiler_argv)
    ):
        raise RuntimeError("frontend job argv must be a non-empty list of strings")

    return _SourceKitClient(
        source_file=source_file,
        compiler_argv=compiler_argv,
        structure=structure,
        daemon=SourceKitDaemon(),
    )


def get(client: _SourceKitClient, key: int | str) -> object:
    return client.get(key)
