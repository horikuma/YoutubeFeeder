#!/usr/bin/env python3

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from datetime import datetime
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
PROJECT = REPO_ROOT / "YoutubeFeeder.xcodeproj"
SCHEME = "YoutubeFeeder"
DERIVED_DATA_BASE = Path.home() / "Library" / "Caches" / "Codex" / "YoutubeFeeder"
DERIVED_DATA = DERIVED_DATA_BASE / "DerivedData"
METRICS_DIR = REPO_ROOT / ".metrics"
METRICS_DOC = REPO_ROOT / "docs" / "history" / "metrics-latest.md"
TEST_METRICS_DOC = REPO_ROOT / "docs" / "metrics" / "metrics-test.md"
STARTUP_JSON = METRICS_DIR / "startup-metrics.json"
BUILD_LOG = METRICS_DIR / "build-for-testing.log"
TEST_LOG = METRICS_DIR / "test-without-building.log"
DESTINATION = "platform=iOS Simulator,name=iPhone 12 mini"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Collect build, test, and startup metrics.")
    parser.add_argument("--label", required=True)
    parser.add_argument("--change-kind", default="source")
    parser.add_argument("--manual-retries", type=int, default=0)
    parser.add_argument("--auto-retry-limit", type=int, default=0)
    return parser.parse_args()


def now_seconds() -> float:
    return datetime.now().timestamp()


def run_command(command: list[str], *, log_path: Path, env: dict[str, str] | None = None) -> None:
    with log_path.open("w", encoding="utf-8") as handle:
        process = subprocess.run(
            command,
            stdout=handle,
            stderr=subprocess.STDOUT,
            env=env,
            check=False,
        )
    if process.returncode != 0:
        raise SystemExit(f"Command failed. See {log_path}")


def render_test_metrics(log_paths: list[Path]) -> None:
    command = [
        sys.executable,
        str(Path(__file__).with_name("render-test-metrics.py")),
        str(REPO_ROOT),
        str(TEST_METRICS_DOC),
        *[str(path) for path in log_paths],
    ]
    process = subprocess.run(command, check=False)
    if process.returncode != 0:
        raise SystemExit(process.returncode)


def read_startup_payload() -> dict:
    if STARTUP_JSON.exists():
        return json.loads(STARTUP_JSON.read_text(encoding="utf-8"))

    if not TEST_LOG.exists():
        return {}

    marker = "YOUTUBEFEEDER_STARTUP_METRICS "
    for line in reversed(TEST_LOG.read_text(encoding="utf-8", errors="ignore").splitlines()):
        if marker in line:
            return json.loads(line.split(marker, 1)[1].strip())
    return {}


def update_metrics_doc(
    *,
    today: str,
    label: str,
    change_kind: str,
    build_duration: float,
    test_duration: float,
    total_duration: float,
    manual_retries: int,
    auto_retries: int,
) -> None:
    payload = read_startup_payload()
    startup_metrics = payload.get("startup_metrics", {})

    entry_lines = [
        f"### {label}",
        f"- 種別: {change_kind}",
        f"- 実行環境: `{DESTINATION}`",
    ]
    if change_kind == "source":
        entry_lines.extend(
            [
                f"- build-for-testing: `{build_duration:.3f}s`",
                f"- test-without-building: `{test_duration:.3f}s`",
                f"- 検証合計時間: `{total_duration:.3f}s`",
                f"- 手修正後の再試行回数: `{manual_retries}`",
                f"- 同一コマンド内の自動再試行回数: `{auto_retries}`",
                f"- 起動からスプラッシュ表示まで: `{startup_metrics.get('app_launch_to_splash_ms', 'n/a')}ms`",
                f"- スプラッシュ表示からホーム表示まで: `{startup_metrics.get('splash_to_home_ms', 'n/a')}ms`",
                f"- 起動からホーム表示まで: `{startup_metrics.get('app_launch_to_home_ms', 'n/a')}ms`",
                f"- 起動から bootstrap 読込完了まで: `{startup_metrics.get('app_launch_to_bootstrap_ms', 'n/a')}ms`",
                f"- 起動からホーム遷移開始まで: `{startup_metrics.get('app_launch_to_maintenance_enter_ms', 'n/a')}ms`",
            ]
        )
    else:
        entry_lines.extend(["- 計測: `skip`", "- 理由: ドキュメントのみの変更のため"])

    heading = f"## {today}"
    content = METRICS_DOC.read_text(encoding="utf-8") if METRICS_DOC.exists() else "# YoutubeFeeder Metrics\n"
    entry = "\n".join(entry_lines)
    if heading in content:
        prefix, rest = content.split(heading, 1)
        updated = f"{prefix}{heading}\n{entry}\n\n{rest.lstrip()}"
    else:
        updated = content.rstrip("\n") + f"\n\n{heading}\n{entry}\n"
    METRICS_DOC.write_text(updated, encoding="utf-8")


def main() -> int:
    args = parse_args()
    METRICS_DIR.mkdir(parents=True, exist_ok=True)
    DERIVED_DATA_BASE.mkdir(parents=True, exist_ok=True)
    for path in (STARTUP_JSON, BUILD_LOG, TEST_LOG):
        if path.exists():
            path.unlink()

    build_start = now_seconds()
    run_command(
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
        log_path=BUILD_LOG,
    )
    build_end = now_seconds()

    auto_retries = 0
    test_start = test_end = now_seconds()
    while auto_retries <= args.auto_retry_limit:
        if STARTUP_JSON.exists():
            STARTUP_JSON.unlink()
        test_start = now_seconds()
        with TEST_LOG.open("w", encoding="utf-8") as handle:
            process = subprocess.run(
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
                    "CODE_SIGNING_ALLOWED=NO",
                    "CODE_SIGNING_REQUIRED=NO",
                ],
                stdout=handle,
                stderr=subprocess.STDOUT,
                env={**os.environ, "YOUTUBEFEEDER_STARTUP_METRICS_OUTPUT": str(STARTUP_JSON)},
                check=False,
            )
        test_end = now_seconds()
        if process.returncode == 0:
            break
        auto_retries += 1
    else:
        raise SystemExit(f"test-without-building failed. See {TEST_LOG}")

    render_test_metrics([TEST_LOG])

    build_duration = build_end - build_start
    test_duration = test_end - test_start
    total_duration = build_duration + test_duration
    today = datetime.now().astimezone().strftime("%Y/%m/%d")
    update_metrics_doc(
        today=today,
        label=args.label,
        change_kind=args.change_kind,
        build_duration=build_duration,
        test_duration=test_duration,
        total_duration=total_duration,
        manual_retries=args.manual_retries,
        auto_retries=auto_retries,
    )
    print(f"Updated {METRICS_DOC}")
    print(f"build-for-testing: {build_duration:.3f}s")
    print(f"test-without-building: {test_duration:.3f}s")
    print(f"verification total: {total_duration:.3f}s")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
