#!/usr/bin/env python3

from __future__ import annotations

import subprocess
import sys
from pathlib import Path


SCHEME_NAME = "YoutubeFeeder"
CONFIGURATIONS = {
    "debug": "Debug",
    "release": "Release",
}


def resolve_repo_root() -> Path:
    return Path(__file__).resolve().parents[2]


def resolve_mode(argv: list[str]) -> str | None:
    if len(argv) != 2:
        print("usage: build.py <debug|release>", file=sys.stderr)
        return None

    mode = argv[1].lower()
    if mode not in CONFIGURATIONS:
        print("build mode must be debug or release", file=sys.stderr)
        return None
    return mode


def run_build(mode: str) -> int:
    repo_root = resolve_repo_root()
    derived_data_path = repo_root / "build" / mode
    derived_data_path.mkdir(parents=True, exist_ok=True)

    process = subprocess.run(
        [
            "xcodebuild",
            "-scheme",
            SCHEME_NAME,
            "-configuration",
            CONFIGURATIONS[mode],
            "-destination",
            "platform=macOS",
            "-derivedDataPath",
            str(derived_data_path),
            "CODE_SIGNING_ALLOWED=NO",
            "CODE_SIGNING_REQUIRED=NO",
            "CODE_SIGN_IDENTITY=",
            "build",
        ],
        check=False,
    )
    return process.returncode


def main() -> int:
    mode = resolve_mode(sys.argv)
    if mode is None:
        return 2
    return run_build(mode)


if __name__ == "__main__":
    raise SystemExit(main())
