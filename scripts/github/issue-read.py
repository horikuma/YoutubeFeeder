#!/usr/bin/env python3

from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path


def parse_args() -> tuple[argparse.Namespace, list[str]]:
    parser = argparse.ArgumentParser(add_help=False)
    parser.add_argument("--body-file")
    return parser.parse_known_args()


def main() -> int:
    args, remaining = parse_args()
    target = Path(__file__).with_name("issue.py")
    process = subprocess.run(
        [sys.executable, str(target), "show", *remaining],
        capture_output=bool(args.body_file),
        text=True,
        check=False,
    )
    if process.returncode != 0:
        if process.stderr:
            sys.stderr.write(process.stderr)
        return process.returncode

    if args.body_file:
        Path(args.body_file).write_text(process.stdout, encoding="utf-8")
        sys.stdout.write(process.stdout)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
