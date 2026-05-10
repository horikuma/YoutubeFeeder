#!/usr/bin/env python3

from __future__ import annotations

import json
import sys
from pathlib import Path

from sourcekit_client.frontend_jobs import DEFAULT_FRONTEND_JOBS_PATH, extract_frontend_jobs


def usage(error: str | None = None) -> int:
    if error:
        print(f"error: {error}", file=sys.stderr)
    print("Usage: extract.py <raw-build-log>", file=sys.stderr)
    return 2 if error else 0


def main() -> int:
    if len(sys.argv) != 2 or sys.argv[1] in {"-h", "--help"}:
        return usage(None if len(sys.argv) == 2 and sys.argv[1] in {"-h", "--help"} else "expected one raw log path")

    raw_log_path = Path(sys.argv[1]).expanduser().resolve()
    if not raw_log_path.exists():
        return usage(f"file not found: {raw_log_path}")

    jobs = extract_frontend_jobs(raw_log_path, DEFAULT_FRONTEND_JOBS_PATH)
    json.dump({"jobs": jobs}, sys.stdout, ensure_ascii=False, indent=2)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
