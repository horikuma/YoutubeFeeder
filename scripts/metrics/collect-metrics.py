#!/usr/bin/env python3

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
from datetime import datetime
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
PROJECT = REPO_ROOT / "YoutubeFeeder.xcodeproj"
SCHEME = "YoutubeFeeder"
DERIVED_DATA_BASE = Path.home() / "Library" / "Caches" / "Codex" / "YoutubeFeeder"
DERIVED_DATA = DERIVED_DATA_BASE / "DerivedData"
METRICS_DIR = REPO_ROOT / ".metrics"
METRICS_DOC = REPO_ROOT / "docs" / "history" / "metrics-latest.md"
HISTORY_JSON_DOC = REPO_ROOT / "docs" / "metrics" / "metrics-history.json"
STARTUP_JSON = METRICS_DIR / "startup-metrics.json"
BUILD_LOG = METRICS_DIR / "build-for-testing.log"
STARTUP_TEST_LOG = METRICS_DIR / "startup-test.log"
PREFERRED_DEVICE_NAMES = ["iPhone 17", "iPhone 12 mini"]
STARTUP_ONLY_TEST_ID = "YoutubeFeederUITests/HomeScreenUITests/testHomeStartupMetrics"
SECONDS_PATTERN = re.compile(r"`(?P<value>[0-9.]+)s`$")
MILLISECONDS_PATTERN = re.compile(r"`(?P<value>[0-9]+)ms`$")
BACKTICK_PATTERN = re.compile(r"`(?P<value>.*)`$")


def resolve_destination() -> tuple[str, str]:
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
    candidates: dict[str, tuple[tuple[int, ...], str, str]] = {}
    runtime_pattern = re.compile(r"-- iOS ([0-9.]+) --")
    device_pattern = re.compile(r"^\s+(?P<name>.+?) \((?P<uuid>[A-F0-9-]+)\) \(Shutdown\)\s*$")
    booted_pattern = re.compile(r"^\s+(?P<name>.+?) \((?P<uuid>[A-F0-9-]+)\) \(Booted\)\s*$")

    for line in result.stdout.splitlines():
        runtime_match = runtime_pattern.match(line.strip())
        if runtime_match:
            current_runtime = tuple(int(part) for part in runtime_match.group(1).split("."))
            continue

        device_match = device_pattern.match(line) or booted_pattern.match(line)
        if not device_match or current_runtime is None:
            continue

        name = device_match.group("name")
        uuid = device_match.group("uuid")
        if name not in PREFERRED_DEVICE_NAMES:
            continue

        existing = candidates.get(name)
        if existing is None or current_runtime > existing[0]:
            destination = f"platform=iOS Simulator,id={uuid}"
            display = f"platform=iOS Simulator,name={name},OS={'.'.join(str(part) for part in current_runtime)}"
            candidates[name] = (current_runtime, destination, display)

    for name in PREFERRED_DEVICE_NAMES:
        if name in candidates:
            _, destination, display = candidates[name]
            return destination, display

    raise SystemExit(f"No preferred simulator available: {', '.join(PREFERRED_DEVICE_NAMES)}")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Collect build and startup metrics.")
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


def run_startup_metrics_test(*, destination: str) -> float:
    start_at = now_seconds()
    run_command(
        [
            "xcodebuild",
            "test-without-building",
            "-project",
            str(PROJECT),
            "-scheme",
            SCHEME,
            "-destination",
            destination,
            "-derivedDataPath",
            str(DERIVED_DATA),
            f"-only-testing:{STARTUP_ONLY_TEST_ID}",
            "CODE_SIGNING_ALLOWED=NO",
            "CODE_SIGNING_REQUIRED=NO",
        ],
        log_path=STARTUP_TEST_LOG,
        env={**os.environ, "YOUTUBEFEEDER_STARTUP_METRICS_OUTPUT": str(STARTUP_JSON)},
    )
    return now_seconds() - start_at


def read_startup_payload() -> dict:
    if STARTUP_JSON.exists():
        return json.loads(STARTUP_JSON.read_text(encoding="utf-8"))

    if not STARTUP_TEST_LOG.exists():
        return {}

    marker = "YOUTUBEFEEDER_STARTUP_METRICS "
    for line in reversed(STARTUP_TEST_LOG.read_text(encoding="utf-8", errors="ignore").splitlines()):
        if marker in line:
            return json.loads(line.split(marker, 1)[1].strip())
    return {}


def parse_seconds(text: str) -> float | None:
    match = SECONDS_PATTERN.search(text)
    if match is None:
        return None
    return float(match.group("value"))


def parse_milliseconds(text: str) -> int | None:
    match = MILLISECONDS_PATTERN.search(text)
    if match is None:
        return None
    return int(match.group("value"))


def parse_backtick_value(text: str) -> str | None:
    match = BACKTICK_PATTERN.search(text)
    if match is None:
        return None
    return match.group("value")


def parse_history_entry(label: str, details: list[str]) -> dict[str, object]:
    entry: dict[str, object] = {
        "kind": "metrics_entry",
        "label": label,
        "extra_lines": [],
    }
    startup_metrics: dict[str, int | str] = {}
    for detail in details:
        if detail.startswith("種別: "):
            entry["change_kind"] = detail.removeprefix("種別: ")
        elif detail.startswith("実行環境: "):
            entry["destination_display"] = parse_backtick_value(detail) or detail.removeprefix("実行環境: ")
        elif detail.startswith("build-for-testing: "):
            entry["build_duration_seconds"] = parse_seconds(detail)
        elif detail.startswith("test-without-building: "):
            entry["test_duration_seconds"] = parse_seconds(detail)
        elif detail.startswith("startup test-without-building: "):
            entry["startup_test_duration_seconds"] = parse_seconds(detail)
        elif detail.startswith("検証合計時間: "):
            entry["total_duration_seconds"] = parse_seconds(detail)
        elif detail.startswith("手修正後の再試行回数: "):
            entry["manual_retries"] = int(parse_backtick_value(detail) or detail.removeprefix("手修正後の再試行回数: "))
        elif detail.startswith("同一コマンド内の自動再試行回数: "):
            entry["auto_retries"] = int(parse_backtick_value(detail) or detail.removeprefix("同一コマンド内の自動再試行回数: "))
        elif detail.startswith("計測: "):
            entry["measurement"] = parse_backtick_value(detail) or detail.removeprefix("計測: ")
        elif detail.startswith("理由: "):
            entry["reason"] = detail.removeprefix("理由: ")
        elif detail.startswith("起動からスプラッシュ表示まで: "):
            startup_metrics["app_launch_to_splash_ms"] = parse_milliseconds(detail) or "n/a"
        elif detail.startswith("スプラッシュ表示からホーム表示まで: "):
            startup_metrics["splash_to_home_ms"] = parse_milliseconds(detail) or "n/a"
        elif detail.startswith("起動からホーム表示まで: "):
            startup_metrics["app_launch_to_home_ms"] = parse_milliseconds(detail) or "n/a"
        elif detail.startswith("起動から bootstrap 読込完了まで: "):
            startup_metrics["app_launch_to_bootstrap_ms"] = parse_milliseconds(detail) or "n/a"
        elif detail.startswith("起動からホーム遷移開始まで: "):
            startup_metrics["app_launch_to_maintenance_enter_ms"] = parse_milliseconds(detail) or "n/a"
        else:
            extra_lines = entry.setdefault("extra_lines", [])
            assert isinstance(extra_lines, list)
            extra_lines.append(detail)
    if startup_metrics:
        entry["startup_metrics"] = startup_metrics
    return entry


def migrate_history_markdown() -> dict[str, object]:
    payload: dict[str, object] = {"days": []}
    if not METRICS_DOC.exists():
        return payload

    lines = METRICS_DOC.read_text(encoding="utf-8").splitlines()
    current_day: dict[str, object] | None = None
    index = 0
    while index < len(lines):
        line = lines[index]
        if line.startswith("## "):
            current_day = {"date": line.removeprefix("## "), "items": []}
            days = payload.setdefault("days", [])
            assert isinstance(days, list)
            days.append(current_day)
            index += 1
            continue
        if current_day is None or not line:
            index += 1
            continue
        if line.startswith("### "):
            details: list[str] = []
            index += 1
            while index < len(lines):
                detail_line = lines[index]
                if not detail_line:
                    index += 1
                    break
                if detail_line.startswith("## ") or detail_line.startswith("### "):
                    break
                if detail_line.startswith("- "):
                    details.append(detail_line.removeprefix("- "))
                index += 1
            items = current_day.setdefault("items", [])
            assert isinstance(items, list)
            items.append(parse_history_entry(line.removeprefix("### "), details))
            continue
        if line.startswith("- "):
            items = current_day.setdefault("items", [])
            assert isinstance(items, list)
            items.append({"kind": "note", "text": line.removeprefix("- ")})
        index += 1
    return payload


def load_history_payload() -> dict[str, object]:
    if HISTORY_JSON_DOC.exists():
        return json.loads(HISTORY_JSON_DOC.read_text(encoding="utf-8"))
    return migrate_history_markdown()


def write_history_payload(payload: dict[str, object]) -> None:
    HISTORY_JSON_DOC.parent.mkdir(parents=True, exist_ok=True)
    HISTORY_JSON_DOC.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def format_startup_metric(value: object) -> str:
    if isinstance(value, int):
        return f"`{value}ms`"
    return f"`{value}`"


def render_history_markdown(payload: dict[str, object]) -> str:
    lines: list[str] = []
    days = payload.get("days", [])
    assert isinstance(days, list)
    for day_index, day in enumerate(days):
        if day_index > 0:
            lines.append("")
        lines.append(f"## {day['date']}")
        items = day.get("items", [])
        assert isinstance(items, list)
        for item_index, item in enumerate(items):
            if item.get("kind") == "note":
                lines.append(f"- {item['text']}")
                continue
            lines.append(f"### {item['label']}")
            lines.append(f"- 種別: {item['change_kind']}")
            lines.append(f"- 実行環境: `{item['destination_display']}`")
            if item.get("measurement") == "skip":
                lines.append("- 計測: `skip`")
                reason = item.get("reason", "ドキュメントのみの変更のため")
                lines.append(f"- 理由: {reason}")
            else:
                if item.get("build_duration_seconds") is not None:
                    lines.append(f"- build-for-testing: `{item['build_duration_seconds']:.3f}s`")
                if item.get("test_duration_seconds") is not None:
                    lines.append(f"- test-without-building: `{item['test_duration_seconds']:.3f}s`")
                if item.get("startup_test_duration_seconds") is not None:
                    lines.append(
                        f"- startup test-without-building: `{item['startup_test_duration_seconds']:.3f}s`"
                    )
                if item.get("total_duration_seconds") is not None:
                    lines.append(f"- 検証合計時間: `{item['total_duration_seconds']:.3f}s`")
                if item.get("manual_retries") is not None:
                    lines.append(f"- 手修正後の再試行回数: `{item['manual_retries']}`")
                if item.get("auto_retries") is not None:
                    lines.append(f"- 同一コマンド内の自動再試行回数: `{item['auto_retries']}`")
                startup_metrics = item.get("startup_metrics", {})
                if isinstance(startup_metrics, dict):
                    startup_lines = [
                        ("起動からスプラッシュ表示まで", startup_metrics.get("app_launch_to_splash_ms")),
                        ("スプラッシュ表示からホーム表示まで", startup_metrics.get("splash_to_home_ms")),
                        ("起動からホーム表示まで", startup_metrics.get("app_launch_to_home_ms")),
                        ("起動から bootstrap 読込完了まで", startup_metrics.get("app_launch_to_bootstrap_ms")),
                        ("起動からホーム遷移開始まで", startup_metrics.get("app_launch_to_maintenance_enter_ms")),
                    ]
                    for heading, value in startup_lines:
                        if value is None:
                            continue
                        lines.append(f"- {heading}: {format_startup_metric(value)}")
            extra_lines = item.get("extra_lines", [])
            if isinstance(extra_lines, list):
                for extra_line in extra_lines:
                    lines.append(f"- {extra_line}")
            if item_index < len(items) - 1:
                lines.append("")
    return "\n".join(lines) + "\n"


def update_metrics_outputs(
    *,
    today: str,
    label: str,
    change_kind: str,
    destination_display: str,
    build_duration: float,
    startup_test_duration: float,
    total_duration: float,
    manual_retries: int,
    auto_retries: int,
) -> None:
    payload = load_history_payload()
    startup_payload = read_startup_payload()
    days = payload.setdefault("days", [])
    assert isinstance(days, list)

    day = next((item for item in days if item.get("date") == today), None)
    if day is None:
        day = {"date": today, "items": []}
        days.insert(0, day)
    items = day.setdefault("items", [])
    assert isinstance(items, list)

    entry: dict[str, object] = {
        "kind": "metrics_entry",
        "label": label,
        "change_kind": change_kind,
        "destination_display": destination_display,
        "manual_retries": manual_retries,
        "auto_retries": auto_retries,
        "extra_lines": [],
    }
    if change_kind == "docs":
        entry["measurement"] = "skip"
        entry["reason"] = "ドキュメントのみの変更のため"
    else:
        entry["build_duration_seconds"] = build_duration
        entry["startup_test_duration_seconds"] = startup_test_duration
        entry["total_duration_seconds"] = total_duration
        entry["startup_metrics"] = startup_payload.get("startup_metrics", {})
    items.insert(0, entry)

    write_history_payload(payload)
    METRICS_DOC.write_text(render_history_markdown(payload), encoding="utf-8")


def main() -> int:
    args = parse_args()
    METRICS_DIR.mkdir(parents=True, exist_ok=True)
    DERIVED_DATA_BASE.mkdir(parents=True, exist_ok=True)
    for path in (STARTUP_JSON, BUILD_LOG, STARTUP_TEST_LOG):
        if path.exists():
            path.unlink()

    auto_retries = 0
    build_duration = 0.0
    startup_test_duration = 0.0
    destination_display = "skip"

    if args.change_kind != "docs":
        destination, destination_display = resolve_destination()
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
                destination,
                "-derivedDataPath",
                str(DERIVED_DATA),
                "CODE_SIGNING_ALLOWED=NO",
                "CODE_SIGNING_REQUIRED=NO",
            ],
            log_path=BUILD_LOG,
        )
        build_duration = now_seconds() - build_start

        while auto_retries <= args.auto_retry_limit:
            if STARTUP_JSON.exists():
                STARTUP_JSON.unlink()
            try:
                startup_test_duration = run_startup_metrics_test(destination=destination)
                break
            except SystemExit:
                auto_retries += 1
                if auto_retries > args.auto_retry_limit:
                    raise

    total_duration = build_duration + startup_test_duration
    today = datetime.now().astimezone().strftime("%Y/%m/%d")
    update_metrics_outputs(
        today=today,
        label=args.label,
        change_kind=args.change_kind,
        destination_display=destination_display,
        build_duration=build_duration,
        startup_test_duration=startup_test_duration,
        total_duration=total_duration,
        manual_retries=args.manual_retries,
        auto_retries=auto_retries,
    )
    print(f"Updated {HISTORY_JSON_DOC}")
    print(f"Updated {METRICS_DOC}")
    print(f"build-for-testing: {build_duration:.3f}s")
    print(f"startup test-without-building: {startup_test_duration:.3f}s")
    print(f"verification total: {total_duration:.3f}s")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
