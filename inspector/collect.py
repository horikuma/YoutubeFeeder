#!/usr/bin/env python3

from __future__ import annotations

import subprocess
import sys


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print("Usage: collect.py <source-file>", file=sys.stderr)
        return 2

    source_file = argv[1]
    command = ["sourcekitten", "structure", "--file", source_file]

    result = subprocess.run(command, capture_output=True, text=True)
    if result.stdout:
        sys.stdout.write(result.stdout)
    if result.stderr:
        sys.stderr.write(result.stderr)
    return result.returncode


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
