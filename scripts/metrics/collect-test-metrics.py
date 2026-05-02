#!/usr/bin/env python3

from __future__ import annotations

import argparse
import os
import re
import shutil
import subprocess
import sys
import tempfile
from datetime import datetime
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
PROJECT = REPO_ROOT / "YoutubeFeeder.xcodeproj"
SCHEME = "YoutubeFeeder"
DERIVED_DATA = REPO_ROOT / "build"
COMMAND_RUNNER = REPO_ROOT / "scripts" / "command-runner.py"
PREFERRED_DEVICE_NAMES = ["iPhone 17", "iPhone 12 mini"]
OUTPUT_DOC = REPO_ROOT / "docs" / "metrics" / "metrics-test.md"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Collect focused unit/UI test timing metrics.")
    parser.add_argument("--logic-only-testing", action="append", default=[])
    parser.add_argument("--ui-only-testing", action="append", default=[])
    return parser.parse_args()


def resolve_device() -> tuple[str, str]:
    result = subprocess.run(
        ["xcrun", "simctl", "list", "devices", "available"],
        capture_output=True,
        text=True,
        check=False,
    )
    if result.returncode != 0:
        stderr = result.stderr.strip() or result.stdout.strip()
        raise SystemExit(f"Failed to list simulators: {stderr}")

    current_runtime: tuple[int, ...] | None = None
    candidates: dict[str, tuple[tuple[int, ...], str]] = {}
    runtime_pattern = re.compile(r"-- iOS ([0-9.]+) --")
    device_pattern = re.compile(r"^\s+(?P<name>.+?) \((?P<uuid>[A-F0-9-]+)\) \((Shutdown|Booted)\)\s*$")

    for line in result.stdout.splitlines():
        runtime_match = runtime_pattern.match(line.strip())
        if runtime_match:
            current_runtime = tuple(int(part) for part in runtime_match.group(1).split("."))
            continue

        device_match = device_pattern.match(line)
        if not device_match or current_runtime is None:
            continue

        name = device_match.group("name")
        uuid = device_match.group("uuid")
        if name not in PREFERRED_DEVICE_NAMES:
            continue

        existing = candidates.get(name)
        if existing is None or current_runtime > existing[0]:
            candidates[name] = (current_runtime, uuid)

    for name in PREFERRED_DEVICE_NAMES:
        if name in candidates:
            _, uuid = candidates[name]
            return name, uuid

    raise SystemExit(f"No preferred simulator available: {', '.join(PREFERRED_DEVICE_NAMES)}")


def run_logged(command: list[str], log_path: Path, *, env: dict[str, str] | None = None) -> None:
    with log_path.open("w", encoding="utf-8") as handle:
        process = subprocess.run(command, stdout=handle, stderr=subprocess.STDOUT, env=env, check=False)
    if process.returncode != 0:
        raise SystemExit(f"Command failed. See {log_path}")


def main() -> int:
    args = parse_args()
    DERIVED_DATA.mkdir(parents=True, exist_ok=True)
    tmp_root = Path(
        tempfile.mkdtemp(prefix=f"youtubefeeder-collect-test-metrics-{datetime.now().strftime('%Y%m%d-%H%M%S')}-")
    )
    try:
        metrics_dir = tmp_root / "metrics"
        metrics_dir.mkdir(parents=True, exist_ok=True)
        build_log = tmp_root / "build.log"
        unit_log = tmp_root / "unit.log"
        ui_log = tmp_root / "ui.log"

        device_name, device_uuid = resolve_device()
        destination = f"platform=iOS Simulator,id={device_uuid}"
        subprocess.run(["xcrun", "simctl", "shutdown", device_uuid], check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        subprocess.run(["xcrun", "simctl", "boot", device_uuid], check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        boot = subprocess.run(["xcrun", "simctl", "bootstatus", device_uuid, "-b"], check=False)
        if boot.returncode != 0:
            raise SystemExit(boot.returncode)

        print(f"Building tests on {device_name}...")
        run_logged(
            [
                str(COMMAND_RUNNER),
                "xcodebuild-build-for-testing",
                "-project",
                str(PROJECT),
                "-scheme",
                SCHEME,
                "-destination",
                destination,
                "-derivedDataPath",
                str(DERIVED_DATA),
                "CODE_SIGNING_ALLOWED=NO",
                "CODE_SIGNING_REQUIRED=NO",
            ],
            build_log,
        )

        print(f"Running unit tests on {device_name}...")
        unit_args = [f"-only-testing:{test_id}" for test_id in args.logic_only_testing] or ["-only-testing:YoutubeFeederTests"]
        run_logged(
            [
                str(COMMAND_RUNNER),
                "xcodebuild-test-without-building",
                "-project",
                str(PROJECT),
                "-scheme",
                SCHEME,
                "-destination",
                destination,
                "-derivedDataPath",
                str(DERIVED_DATA),
                *unit_args,
                "CODE_SIGNING_ALLOWED=NO",
                "CODE_SIGNING_REQUIRED=NO",
            ],
            unit_log,
            env={**dict(os.environ), "YOUTUBEFEEDER_TEST_METRICS_DIR": str(metrics_dir)},
        )

        print(f"Running UI tests on {device_name}...")
        ui_args = [f"-only-testing:{test_id}" for test_id in args.ui_only_testing] or ["-only-testing:YoutubeFeederUITests"]
        run_logged(
            [
                str(COMMAND_RUNNER),
                "xcodebuild-test-without-building",
                "-project",
                str(PROJECT),
                "-scheme",
                SCHEME,
                "-destination",
                destination,
                "-derivedDataPath",
                str(DERIVED_DATA),
                *ui_args,
                "CODE_SIGNING_ALLOWED=NO",
                "CODE_SIGNING_REQUIRED=NO",
            ],
            ui_log,
            env={**dict(os.environ), "YOUTUBEFEEDER_TEST_METRICS_DIR": str(metrics_dir)},
        )

        process = subprocess.run(
            [
                sys.executable,
                str(Path(__file__).with_name("render-test-metrics.py")),
                str(REPO_ROOT),
                str(OUTPUT_DOC),
                str(unit_log),
                str(ui_log),
            ],
            check=False,
        )
        return process.returncode
    finally:
        shutil.rmtree(tmp_root, ignore_errors=True)


if __name__ == "__main__":
    raise SystemExit(main())
