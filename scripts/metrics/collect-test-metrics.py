#!/usr/bin/env python3

from __future__ import annotations

import argparse
import os
import shutil
import subprocess
import sys
import tempfile
from datetime import datetime
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
PROJECT = REPO_ROOT / "YoutubeFeeder.xcodeproj"
SCHEME = "YoutubeFeeder"
DERIVED_DATA_BASE = Path.home() / "Library" / "Caches" / "Codex" / "YoutubeFeeder"
DERIVED_DATA = DERIVED_DATA_BASE / "DerivedData"
DESTINATION = "platform=iOS Simulator,name=iPhone 12 mini"
DEVICE_NAME = "iPhone 12 mini"
OUTPUT_DOC = REPO_ROOT / "docs" / "metrics" / "metrics-test.md"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Collect focused unit/UI test timing metrics.")
    parser.add_argument("--logic-only-testing", action="append", default=[])
    parser.add_argument("--ui-only-testing", action="append", default=[])
    return parser.parse_args()


def find_device_uuid() -> str:
    result = subprocess.run(
        ["xcrun", "simctl", "list", "devices", "available"],
        capture_output=True,
        text=True,
        check=False,
    )
    if result.returncode != 0:
        stderr = result.stderr.strip() or result.stdout.strip()
        raise SystemExit(f"Failed to list simulators: {stderr}")

    for line in result.stdout.splitlines():
        if DEVICE_NAME in line and "(" in line and ")" in line:
            start = line.rfind("(")
            end = line.rfind(")")
            if start >= 0 and end > start:
                return line[start + 1 : end]
    raise SystemExit(f"Simulator not installed: {DEVICE_NAME}")


def run_logged(command: list[str], log_path: Path, *, env: dict[str, str] | None = None) -> None:
    with log_path.open("w", encoding="utf-8") as handle:
        process = subprocess.run(command, stdout=handle, stderr=subprocess.STDOUT, env=env, check=False)
    if process.returncode != 0:
        raise SystemExit(f"Command failed. See {log_path}")


def main() -> int:
    args = parse_args()
    DERIVED_DATA_BASE.mkdir(parents=True, exist_ok=True)
    tmp_root = Path(
        tempfile.mkdtemp(prefix=f"youtubefeeder-collect-test-metrics-{datetime.now().strftime('%Y%m%d-%H%M%S')}-")
    )
    try:
        metrics_dir = tmp_root / "metrics"
        metrics_dir.mkdir(parents=True, exist_ok=True)
        build_log = tmp_root / "build.log"
        unit_log = tmp_root / "unit.log"
        ui_log = tmp_root / "ui.log"

        device_uuid = find_device_uuid()
        subprocess.run(["xcrun", "simctl", "shutdown", device_uuid], check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        subprocess.run(["xcrun", "simctl", "boot", device_uuid], check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        boot = subprocess.run(["xcrun", "simctl", "bootstatus", device_uuid, "-b"], check=False)
        if boot.returncode != 0:
            raise SystemExit(boot.returncode)

        print("Building tests...")
        run_logged(
            [
                "xcodebuild",
                "build-for-testing",
                "-project",
                str(PROJECT),
                "-scheme",
                SCHEME,
                "-destination",
                DESTINATION,
                "-derivedDataPath",
                str(DERIVED_DATA),
                "CODE_SIGNING_ALLOWED=NO",
                "CODE_SIGNING_REQUIRED=NO",
            ],
            build_log,
        )

        print("Running unit tests...")
        unit_args = [f"-only-testing:{test_id}" for test_id in args.logic_only_testing] or ["-only-testing:YoutubeFeederTests"]
        run_logged(
            [
                "xcodebuild",
                "test-without-building",
                "-project",
                str(PROJECT),
                "-scheme",
                SCHEME,
                "-destination",
                DESTINATION,
                "-derivedDataPath",
                str(DERIVED_DATA),
                *unit_args,
                "CODE_SIGNING_ALLOWED=NO",
                "CODE_SIGNING_REQUIRED=NO",
            ],
            unit_log,
            env={**dict(os.environ), "YOUTUBEFEEDER_TEST_METRICS_DIR": str(metrics_dir)},
        )

        print("Running UI tests...")
        ui_args = [f"-only-testing:{test_id}" for test_id in args.ui_only_testing] or ["-only-testing:YoutubeFeederUITests"]
        run_logged(
            [
                "xcodebuild",
                "test-without-building",
                "-project",
                str(PROJECT),
                "-scheme",
                SCHEME,
                "-destination",
                DESTINATION,
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
