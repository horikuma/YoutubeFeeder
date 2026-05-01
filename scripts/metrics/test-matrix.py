#!/usr/bin/env python3

from __future__ import annotations

import re
import subprocess
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
PROJECT = REPO_ROOT / "YoutubeFeeder.xcodeproj"
SCHEME = "YoutubeFeeder"
DERIVED_DATA = REPO_ROOT / "build"
PREFERRED_DESTINATIONS = ["iPhone 17", "iPhone 12 mini"]


def available_devices() -> str:
    result = subprocess.run(
        ["xcrun", "simctl", "list", "devices", "available"],
        capture_output=True,
        text=True,
        check=False,
    )
    if result.returncode != 0:
        stderr = result.stderr.strip() or result.stdout.strip()
        raise SystemExit(f"Failed to list simulators: {stderr}")
    return result.stdout


def resolve_destinations(devices_text: str) -> list[tuple[str, str]]:
    current_runtime: tuple[int, ...] | None = None
    candidates: dict[str, tuple[tuple[int, ...], str]] = {}
    runtime_pattern = re.compile(r"-- iOS ([0-9.]+) --")
    device_pattern = re.compile(r"^\s+(?P<name>.+?) \((?P<uuid>[A-F0-9-]+)\) \((Shutdown|Booted)\)\s*$")

    for line in devices_text.splitlines():
        runtime_match = runtime_pattern.match(line.strip())
        if runtime_match:
            current_runtime = tuple(int(part) for part in runtime_match.group(1).split("."))
            continue

        device_match = device_pattern.match(line)
        if not device_match or current_runtime is None:
            continue

        name = device_match.group("name")
        uuid = device_match.group("uuid")
        if name not in PREFERRED_DESTINATIONS:
            continue

        existing = candidates.get(name)
        if existing is None or current_runtime > existing[0]:
            candidates[name] = (current_runtime, uuid)

    resolved: list[tuple[str, str]] = []
    for device_name in PREFERRED_DESTINATIONS:
        if device_name in candidates:
            _, uuid = candidates[device_name]
            resolved.append((device_name, uuid))
    return resolved


def main() -> int:
    DERIVED_DATA.mkdir(parents=True, exist_ok=True)
    devices_text = available_devices()
    destinations = resolve_destinations(devices_text)
    if not destinations:
        print(f"Skipping test matrix: no preferred simulator installed ({', '.join(PREFERRED_DESTINATIONS)})")
        return 0

    for device_name, uuid in destinations:

        print(f"Running tests on {device_name} ({uuid})")
        subprocess.run(["xcrun", "simctl", "bootstatus", uuid, "-b"], check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        subprocess.run(["xcrun", "simctl", "boot", uuid], check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        bootstatus = subprocess.run(["xcrun", "simctl", "bootstatus", uuid, "-b"], check=False)
        if bootstatus.returncode != 0:
            return bootstatus.returncode

        process = subprocess.run(
            [
                "xcodebuild",
                "test",
                "-project",
                str(PROJECT),
                "-scheme",
                SCHEME,
                "-destination",
                f"platform=iOS Simulator,id={uuid}",
                "-derivedDataPath",
                str(DERIVED_DATA),
                "CODE_SIGNING_ALLOWED=NO",
                "CODE_SIGNING_REQUIRED=NO",
            ],
            check=False,
        )
        if process.returncode != 0:
            return process.returncode
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
