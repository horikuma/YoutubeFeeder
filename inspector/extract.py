#!/usr/bin/env python3

from __future__ import annotations

import json
import shlex
import sys
from pathlib import Path

MARKER = "builtin-Swift-Compilation -- "


def usage(error: str | None = None) -> int:
    if error:
        print(f"error: {error}", file=sys.stderr)
    print("Usage: extract.py <raw-build-log>", file=sys.stderr)
    return 2 if error else 0


def extract_jobs(raw_log_path: Path) -> list[dict[str, object]]:
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


def main() -> int:
    if len(sys.argv) != 2 or sys.argv[1] in {"-h", "--help"}:
        return usage(None if len(sys.argv) == 2 and sys.argv[1] in {"-h", "--help"} else "expected one raw log path")

    raw_log_path = Path(sys.argv[1]).expanduser().resolve()
    if not raw_log_path.exists():
        return usage(f"file not found: {raw_log_path}")

    jobs = extract_jobs(raw_log_path)
    payload = {"jobs": jobs}

    ROOT = Path(__file__).resolve().parent
    FRONTEND_JOBS_PATH = ROOT / "frontend-jobs.json"
    FRONTEND_JOBS_PATH.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    json.dump(payload, sys.stdout, ensure_ascii=False, indent=2)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
