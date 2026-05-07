#!/usr/bin/env python3

from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any


def flatten(value: Any, prefix: str = "") -> list[tuple[str, Any]]:
    if isinstance(value, dict):
        items: list[tuple[str, Any]] = []
        for key, child in value.items():
            next_prefix = f"{prefix}.{key}" if prefix else str(key)
            items.extend(flatten(child, next_prefix))
        return items
    if isinstance(value, list):
        items = []
        for index, child in enumerate(value):
            next_prefix = f"{prefix}[{index}]" if prefix else f"[{index}]"
            items.extend(flatten(child, next_prefix))
        return items
    return [(prefix, value)]


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print("Usage: view.py <json-file>", file=sys.stderr)
        return 2

    json_path = Path(argv[1])
    with json_path.open(encoding="utf-8") as handle:
        data = json.load(handle)

    for path, value in flatten(data):
        if path:
            print(f"{path} = {json.dumps(value, ensure_ascii=False)}")
        else:
            print(json.dumps(value, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
