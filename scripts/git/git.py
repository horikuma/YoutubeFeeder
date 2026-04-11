#!/usr/bin/env python3

from __future__ import annotations

import subprocess
import sys
from pathlib import Path


def resolve_repo_root() -> Path:
    return Path(__file__).resolve().parents[2]


def main() -> int:
    git_args = sys.argv[1:]
    if not git_args:
        print("git wrapper requires at least one git argument", file=sys.stderr)
        return 2

    repo_root = resolve_repo_root()
    process = subprocess.run(
        ["git", "-C", str(repo_root), *git_args],
        check=False,
    )
    return process.returncode


if __name__ == "__main__":
    raise SystemExit(main())
