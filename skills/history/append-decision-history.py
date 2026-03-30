#!/usr/bin/env python3

from __future__ import annotations

import subprocess
import sys
from pathlib import Path


def main() -> int:
    target = Path(__file__).with_name("append-history.py")
    process = subprocess.run([sys.executable, str(target), "decision", *sys.argv[1:]], check=False)
    return process.returncode


if __name__ == "__main__":
    raise SystemExit(main())
