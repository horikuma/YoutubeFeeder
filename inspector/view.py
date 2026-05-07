#!/usr/bin/env python3

from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any


def collect_nodes(source: Any, nodes: list[dict[str, Any]]) -> None:
    if not isinstance(source, dict):
        print("collect_nodes failed", file=sys.stderr)
        return

    kind = source.get("key.kind")
    if kind == "source.lang.swift.expr.call":
        wl = ["key.name", "key.kind"]
        node = {key: child for key, child in source.items() if key in wl}
        nodes.append(node)
        print(json.dumps(node, ensure_ascii=False))

    substructure = source.get("key.substructure")
    if isinstance(substructure, list):
        for child in substructure:
            collect_nodes(child, nodes)


def main(argv: list[str]) -> int:
    if len(argv) > 2:
        print("Usage: view.py [json-file]", file=sys.stderr)
        return 2

    if len(argv) == 2:
        json_path = Path(argv[1])
    else:
        json_path = Path(__file__).with_name("collect.json")

    with json_path.open(encoding="utf-8") as handle:
        source = json.load(handle)

    nodes: list[dict[str, Any]] = []
    collect_nodes(source, nodes)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
