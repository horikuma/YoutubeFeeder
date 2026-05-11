#!/usr/bin/env python3
"""SourceKit client helpers."""

from __future__ import annotations

import json
import subprocess
from dataclasses import dataclass, field
from pathlib import Path

from .daemon import SourceKitDaemon
from .frontend_jobs import load_builtin_swift_compilation_jobs, select_builtin_swift_compilation_job

PROJECT_ROOT = Path(__file__).resolve().parents[2]


def _run_command(args: list[str]) -> subprocess.CompletedProcess[str]:
    print(args, flush=True)
    return subprocess.run(args, check=True, text=True, capture_output=True)


def _load_structure(file_path: Path) -> dict:
    result = _run_command(["sourcekitten", "structure", "--file", str(file_path)])
    return json.loads(result.stdout)


@dataclass
class _SourceKitClient:
    source_file: Path
    compiler_argv: list[str]
    structure: dict
    daemon: SourceKitDaemon
    owns_daemon: bool = True
    usr_cache: dict[int, str | None] = field(default_factory=dict)

    def __enter__(self) -> "_SourceKitClient":
        return self

    def __exit__(self, exc_type, exc, tb) -> None:
        self.close()

    @property
    def request_count(self) -> int:
        return self.daemon.request_count

    def close(self) -> None:
        if self.owns_daemon:
            self.daemon.close()

    def get(self, key: int | str) -> object:
        if key == "structure":
            return self.structure
        if key == "collect":
            from .collect_data import build_collect_dataset

            return build_collect_dataset(self)
        if isinstance(key, int):
            if key not in self.usr_cache:
                print(f"cursorinfo request queued: file={self.source_file} offset={key}", flush=True)
                self.usr_cache[key] = self.daemon.query_usr(
                    self.source_file,
                    key,
                    compiler_argv=self.compiler_argv,
                )
            return self.usr_cache[key]
        raise TypeError(f"unsupported key: {key!r}")


def init(
    source_file: Path,
    raw_build_log_path: Path,
    *,
    debug: bool = False,
    daemon: SourceKitDaemon | None = None,
) -> _SourceKitClient:
    structure = _load_structure(source_file)
    jobs = load_builtin_swift_compilation_jobs(
        raw_build_log_path,
        debug_output_path=PROJECT_ROOT / "llm-temp" / "frontend-jobs.json" if debug else None,
    )
    job = select_builtin_swift_compilation_job(jobs, source_file)

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
        daemon=daemon if daemon is not None else SourceKitDaemon(),
        owns_daemon=daemon is None,
    )


def get(client: _SourceKitClient, key: int | str) -> object:
    return client.get(key)
