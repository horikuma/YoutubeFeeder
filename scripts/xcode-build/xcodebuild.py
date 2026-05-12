#!/usr/bin/env python3

from __future__ import annotations

from pathlib import Path
import subprocess
import sys


DEFAULT_DERIVED_DATA_DIR = "xcodebuild"


def resolve_repo_root() -> Path:
    return Path(__file__).resolve().parents[2]


def ensure_local_derived_data(args: list[str]) -> list[str]:
    if "-derivedDataPath" in args:
        return args

    repo_root = resolve_repo_root()
    derived_data_path = repo_root / "build" / DEFAULT_DERIVED_DATA_DIR
    derived_data_path.mkdir(parents=True, exist_ok=True)
    return [*args, "-derivedDataPath", str(derived_data_path)]


def run_xcodebuild(args: list[str]) -> int:
    repo_root = resolve_repo_root()
    process = subprocess.run(["xcodebuild", *ensure_local_derived_data(args)], cwd=repo_root, check=False)
    return process.returncode


def main() -> int:
    if len(sys.argv) < 2:
        print("usage: xcodebuild.py <xcodebuild args...>", file=sys.stderr)
        return 2

    return run_xcodebuild(sys.argv[1:])


if __name__ == "__main__":
    raise SystemExit(main())
