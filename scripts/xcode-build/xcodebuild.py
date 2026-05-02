#!/usr/bin/env python3

from __future__ import annotations

import subprocess
import sys


def run_xcodebuild(args: list[str]) -> int:
    process = subprocess.run(["xcodebuild", *args], check=False)
    return process.returncode


def main() -> int:
    if len(sys.argv) < 2:
        print("usage: xcodebuild.py <xcodebuild args...>", file=sys.stderr)
        return 2

    return run_xcodebuild(sys.argv[1:])


if __name__ == "__main__":
    raise SystemExit(main())
