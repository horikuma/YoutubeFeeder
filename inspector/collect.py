#!/usr/bin/env python3

from __future__ import annotations

import csv
import json
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any

MODULE_CACHE_PATH = Path("./sourcekitten-module-cache")
CURSORINFO_TIMEOUT_SECONDS = 10.0


def run_command(args: list[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(args, check=False, capture_output=True, text=True)


def discover_sdk_path() -> str:
    result = run_command(["xcrun", "--show-sdk-path"])
    if result.returncode != 0:
        details = result.stderr.strip() or result.stdout.strip() or "xcrun --show-sdk-path failed"
        raise RuntimeError(details)
    sdk_path = result.stdout.strip()
    if not sdk_path:
        raise RuntimeError("xcrun --show-sdk-path returned an empty path")
    return sdk_path


def discover_target_triple() -> str:
    result = run_command(["xcrun", "swift", "-print-target-info"])
    if result.returncode != 0:
        details = result.stderr.strip() or result.stdout.strip() or "xcrun swift -print-target-info failed"
        raise RuntimeError(details)
    payload = json.loads(result.stdout)
    triple = payload["target"]["triple"]
    if not isinstance(triple, str) or not triple:
        raise RuntimeError("xcrun swift -print-target-info returned an invalid target triple")
    return triple


def discover_cursorinfo_compilerargs() -> list[str]:
    MODULE_CACHE_PATH.mkdir(parents=True, exist_ok=True)
    return [
        "-sdk",
        discover_sdk_path(),
        "-target",
        discover_target_triple(),
        "-module-cache-path",
        str(MODULE_CACHE_PATH),
    ]


def discover_swift_files(root: Path) -> list[Path]:
    return sorted(path for path in root.rglob("*.swift") if path.is_file())


def run_sourcekitten_structure(source_file: Path) -> dict[str, Any]:
    try:
        result = run_command(
            ["sourcekitten", "structure", "--file", str(source_file)],
        )
    except FileNotFoundError as error:
        raise RuntimeError("sourcekitten command was not found") from error

    if result.returncode != 0:
        stderr = result.stderr.strip()
        stdout = result.stdout.strip()
        details = stderr or stdout or "sourcekitten returned a non-zero exit status"
        raise RuntimeError(f"sourcekitten structure failed for {source_file}: {details}")

    try:
        payload = json.loads(result.stdout)
    except json.JSONDecodeError as error:
        raise RuntimeError(f"sourcekitten structure returned invalid JSON for {source_file}") from error

    if not isinstance(payload, dict):
        raise RuntimeError(f"sourcekitten structure returned an unexpected payload for {source_file}")

    return payload


def run_sourcekitten_cursorinfo(source_file: Path, offset: int, compilerargs: list[str]) -> dict[str, Any]:
    yaml_text = "\n".join(
        [
            "key.request: source.request.cursorinfo",
            f'key.sourcefile: "{source_file}"',
            f"key.offset: {offset}",
            "key.compilerargs:",
            f'  - "{source_file}"',
            *[f'  - "{arg}"' for arg in compilerargs],
            "",
        ]
    )

    with tempfile.NamedTemporaryFile("w", suffix=".yaml", delete=False) as handle:
        yaml_path = Path(handle.name)
        handle.write(yaml_text)

    try:
        result = subprocess.run(
            ["sourcekitten", "request", "--yaml", str(yaml_path)],
            check=False,
            capture_output=True,
            text=True,
            timeout=CURSORINFO_TIMEOUT_SECONDS,
        )
    except FileNotFoundError as error:
        yaml_path.unlink(missing_ok=True)
        raise RuntimeError("sourcekitten command was not found") from error
    except subprocess.TimeoutExpired:
        return {"key.internal_diagnostic": f"sourcekitten cursorinfo timed out after {CURSORINFO_TIMEOUT_SECONDS:.0f}s"}
    finally:
        yaml_path.unlink(missing_ok=True)

    if result.returncode != 0:
        stderr = result.stderr.strip()
        stdout = result.stdout.strip()
        details = stderr or stdout or "sourcekitten cursorinfo returned a non-zero exit status"
        return {"key.internal_diagnostic": details}

    try:
        payload = json.loads(result.stdout)
    except json.JSONDecodeError:
        return {"key.internal_diagnostic": "sourcekitten cursorinfo returned invalid JSON"}

    if not isinstance(payload, dict):
        return {"key.internal_diagnostic": "sourcekitten cursorinfo returned an unexpected payload"}

    return payload


def flatten_value(prefix: str, value: Any, row: dict[str, str]) -> None:
    if isinstance(value, dict):
        for key, nested in value.items():
            next_prefix = f"{prefix}.{key}" if prefix else key
            flatten_value(next_prefix, nested, row)
        return

    if isinstance(value, list):
        if not value:
            row[prefix] = "[]"
            return

        for index, nested in enumerate(value):
            next_prefix = f"{prefix}.{index}" if prefix else str(index)
            flatten_value(next_prefix, nested, row)
        return

    row[prefix] = "" if value is None else str(value)


def flatten_structure(
    node: dict[str, Any],
    source_path: Path,
    source_file: str,
    node_path: list[int],
    rows: list[dict[str, str]],
    cursorinfo_cache: dict[tuple[str, int], dict[str, Any]],
    compilerargs: list[str],
) -> None:
    row: dict[str, str] = {
        "file": source_file,
        "node_path": ".".join(str(index) for index in node_path) if node_path else "root",
    }

    for key, value in node.items():
        if key == "key.substructure":
            continue
        flatten_value(key, value, row)

    offset = node.get("key.offset")
    if isinstance(offset, int):
        cache_key = (str(source_path), offset)
        cursorinfo = cursorinfo_cache.get(cache_key)
        if cursorinfo is None:
            cursorinfo = run_sourcekitten_cursorinfo(source_path, offset, compilerargs)
            cursorinfo_cache[cache_key] = cursorinfo
        flatten_value("cursorinfo", cursorinfo, row)

    rows.append(row)

    children = node.get("key.substructure", [])
    if not isinstance(children, list):
        return

    for index, child in enumerate(children):
        if isinstance(child, dict):
            flatten_structure(child, source_path, source_file, node_path + [index], rows, cursorinfo_cache, compilerargs)


def collect_rows(root: Path) -> tuple[list[str], list[dict[str, str]]]:
    rows: list[dict[str, str]] = []
    cursorinfo_cache: dict[tuple[str, int], dict[str, Any]] = {}
    compilerargs = discover_cursorinfo_compilerargs()

    for source_file in discover_swift_files(root):
        payload = run_sourcekitten_structure(source_file)
        relative_file = source_file.relative_to(root).as_posix() if source_file.is_relative_to(root) else source_file.as_posix()
        flatten_structure(payload, source_file, relative_file, [], rows, cursorinfo_cache, compilerargs)

    headers = ["file", "node_path"]
    for row in rows:
        for key in row:
            if key not in headers:
                headers.append(key)

    return headers, rows


def main(argv: list[str]) -> int:
    root = Path(argv[1]).resolve() if len(argv) > 1 else Path.cwd().resolve()

    if not root.exists():
        print(f"Root path does not exist: {root}", file=sys.stderr)
        return 1

    try:
        headers, rows = collect_rows(root)
    except RuntimeError as error:
        print(str(error), file=sys.stderr)
        return 1

    writer = csv.DictWriter(sys.stdout, fieldnames=headers, extrasaction="ignore")
    writer.writeheader()
    for row in rows:
        writer.writerow(row)

    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
