#!/usr/bin/env python3

from __future__ import annotations

import subprocess
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
PROJECT = REPO_ROOT / "YoutubeFeeder.xcodeproj"
SCHEME = "YoutubeFeeder"
DERIVED_DATA_BASE = Path.home() / "Library" / "Caches" / "Codex" / "YoutubeFeeder"
DERIVED_DATA = DERIVED_DATA_BASE / "DerivedData"
DESTINATIONS = ["iPhone 12 mini"]


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


def resolve_uuid(devices_text: str, device_name: str) -> str | None:
    for line in devices_text.splitlines():
        if device_name in line and "(" in line and ")" in line:
            start = line.rfind("(")
            end = line.rfind(")")
            if start >= 0 and end > start:
                return line[start + 1 : end]
    return None


def main() -> int:
    DERIVED_DATA_BASE.mkdir(parents=True, exist_ok=True)
    devices_text = available_devices()
    for device_name in DESTINATIONS:
        uuid = resolve_uuid(devices_text, device_name)
        if not uuid:
            print(f"Skipping {device_name}: simulator not installed")
            continue

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
