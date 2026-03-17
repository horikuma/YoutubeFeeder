#!/bin/zsh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT="$REPO_ROOT/HelloWorld.xcodeproj"
SCHEME="HelloWorld"
DERIVED_DATA_BASE="${HOME}/Library/Caches/Codex/HelloWorld"
DERIVED_DATA="$DERIVED_DATA_BASE/DerivedData"
DESTINATION="platform=iOS Simulator,name=iPhone 12 mini"
DEVICE_NAME="iPhone 12 mini"
TMP_METRICS_DIR="$(python3 - <<'PY'
import tempfile
from pathlib import Path
print(Path(tempfile.gettempdir()) / "HelloWorldTestMetrics")
PY
)"
OUTPUT_DOC="$REPO_ROOT/test-metrics.md"
typeset -a LOGIC_ONLY_TESTING=()
typeset -a UI_ONLY_TESTING=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --logic-only-testing)
      LOGIC_ONLY_TESTING+=("$2")
      shift 2
      ;;
    --ui-only-testing)
      UI_ONLY_TESTING+=("$2")
      shift 2
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

mkdir -p "$DERIVED_DATA_BASE"
rm -rf "$TMP_METRICS_DIR"
mkdir -p "$TMP_METRICS_DIR"

available_devices="$(xcrun simctl list devices available)"
device_uuid="$(
  print -r -- "$available_devices" \
    | sed -nE "s/^[[:space:]]+${DEVICE_NAME// /[[:space:]]+} \\(([A-F0-9-]+)\\).*/\\1/p" \
    | head -n 1
)"

if [[ -z "$device_uuid" ]]; then
  echo "Simulator not installed: $DEVICE_NAME" >&2
  exit 1
fi

xcrun simctl shutdown "$device_uuid" >/dev/null 2>&1 || true
xcrun simctl boot "$device_uuid" >/dev/null 2>&1 || true
xcrun simctl bootstatus "$device_uuid" -b >/dev/null

echo "Building tests..."
xcodebuild build-for-testing \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -destination "$DESTINATION" \
  -derivedDataPath "$DERIVED_DATA" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  >/tmp/helloworld-test-metrics-build.log 2>&1

echo "Running unit tests..."
unit_args=("-only-testing:HelloWorldTests")
if (( ${#LOGIC_ONLY_TESTING[@]} > 0 )); then
  unit_args=()
  for test_id in "${LOGIC_ONLY_TESTING[@]}"; do
    unit_args+=("-only-testing:${test_id}")
  done
fi
HELLOWORLD_TEST_METRICS_DIR="$TMP_METRICS_DIR" xcodebuild test-without-building \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -destination "$DESTINATION" \
  -derivedDataPath "$DERIVED_DATA" \
  "${unit_args[@]}" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  >/tmp/helloworld-test-metrics-unit.log 2>&1

echo "Running UI tests..."
ui_args=("-only-testing:HelloWorldUITests")
if (( ${#UI_ONLY_TESTING[@]} > 0 )); then
  ui_args=()
  for test_id in "${UI_ONLY_TESTING[@]}"; do
    ui_args+=("-only-testing:${test_id}")
  done
fi
HELLOWORLD_TEST_METRICS_DIR="$TMP_METRICS_DIR" xcodebuild test-without-building \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -destination "$DESTINATION" \
  -derivedDataPath "$DERIVED_DATA" \
  "${ui_args[@]}" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  >/tmp/helloworld-test-metrics-ui.log 2>&1

python3 - "$REPO_ROOT" "$TMP_METRICS_DIR" "$OUTPUT_DOC" <<'PY'
from __future__ import annotations

import json
import re
import sys
from collections import defaultdict
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path

repo_root = Path(sys.argv[1])
metrics_dir = Path(sys.argv[2])
output_doc = Path(sys.argv[3])
unit_log = Path("/tmp/helloworld-test-metrics-unit.log")
ui_log = Path("/tmp/helloworld-test-metrics-ui.log")


@dataclass
class TestDefinition:
    unique_id: str
    target_kind: str
    area: str
    file_path: str
    class_name: str
    method_name: str
    overview: str


def normalize_test_id(raw: str) -> str:
    if raw.startswith("-[") and raw.endswith("]"):
        inner = raw[2:-1]
        class_part, _, method_part = inner.partition(" ")
        class_name = class_part.split(".")[-1]
        if class_name and method_part:
            return f"{class_name}.{method_part}"
    return raw


def humanize_method_name(method_name: str) -> str:
    text = re.sub(r"^test", "", method_name)
    text = text.replace("_", " ")
    text = re.sub(r"([A-Z]+)([A-Z][a-z])", r"\1 \2", text)
    text = re.sub(r"([a-z0-9])([A-Z])", r"\1 \2", text)
    text = re.sub(r"\s+", " ", text).strip()
    text = text.replace("You Tube", "YouTube")
    if not text:
        return method_name
    return text[0].upper() + text[1:]


def collect_definitions(base: Path, target_kind: str) -> dict[str, TestDefinition]:
    definitions: dict[str, TestDefinition] = {}
    for path in sorted(base.rglob("*Tests.swift")):
        relative = path.relative_to(repo_root).as_posix()
        parts = relative.split("/")
        area = "General"
        if target_kind == "logic":
            if len(parts) >= 3:
                area = parts[2]
        else:
            if len(parts) >= 2:
                area = parts[1]

        current_class = None
        for line in path.read_text().splitlines():
            class_match = re.search(r"class\s+(\w+Tests)\s*:", line)
            if class_match:
                current_class = class_match.group(1)
                continue
            method_match = re.search(r"func\s+(test\w+)\s*\(", line)
            if method_match and current_class:
                method_name = method_match.group(1)
                unique_id = f"{current_class}.{method_name}"
                definitions[unique_id] = TestDefinition(
                    unique_id=unique_id,
                    target_kind=target_kind,
                    area=area,
                    file_path=relative,
                    class_name=current_class,
                    method_name=method_name,
                    overview=humanize_method_name(method_name),
                )
    return definitions


definitions = {}
definitions.update(collect_definitions(repo_root / "HelloWorldTests", "logic"))
definitions.update(collect_definitions(repo_root / "HelloWorldUITests", "ui"))

events_by_test_id: dict[str, dict[str, str | float | None]] = defaultdict(dict)
for path in (unit_log, ui_log):
    if not path.exists():
        continue
    for line in path.read_text(errors="ignore").splitlines():
        marker = "HELLOWORLD_TEST_METRIC "
        if marker not in line:
            continue
        payload = json.loads(line.split(marker, 1)[1])
        test_id = normalize_test_id(payload["testID"])
        event = events_by_test_id[test_id]
        if payload["kind"] == "start":
            event["started_at"] = payload.get("startedAt")
        elif payload["kind"] == "finish":
            event["finished_at"] = payload.get("finishedAt")
            event["duration_seconds"] = payload.get("durationSeconds")


def parse_iso8601(value: str | None) -> datetime | None:
    if not value:
        return None
    return datetime.fromisoformat(value.replace("Z", "+00:00"))


records: list[dict[str, object]] = []
for unique_id, definition in definitions.items():
    event = events_by_test_id.get(unique_id, {})
    if not event:
        continue
    started_at = parse_iso8601(event.get("started_at")) if event else None
    finished_at = parse_iso8601(event.get("finished_at")) if event else None
    duration_seconds = event.get("duration_seconds")
    records.append(
        {
            "unique_id": unique_id,
            "target_kind": definition.target_kind,
            "area": definition.area,
            "file_path": definition.file_path,
            "overview": definition.overview,
            "started_at": started_at,
            "finished_at": finished_at,
            "duration_seconds": float(duration_seconds) if duration_seconds is not None else None,
        }
    )

records.sort(key=lambda item: (item["target_kind"], item["area"], item["unique_id"]))

summary = defaultdict(lambda: {"count": 0, "duration": 0.0})
for record in records:
    key = record["target_kind"]
    summary[key]["count"] += 1
    summary[key]["duration"] += record["duration_seconds"] or 0.0
    area_key = f"{record['target_kind']}::{record['area']}"
    summary[area_key]["count"] += 1
    summary[area_key]["duration"] += record["duration_seconds"] or 0.0

today = datetime.now(timezone.utc).astimezone().strftime("%Y/%m/%d")

lines: list[str] = [
    f"## {today}",
    "",
    "### Summary",
    f"- logic tests: {summary['logic']['count']} cases / {summary['logic']['duration']:.3f}s",
    f"- ui tests: {summary['ui']['count']} cases / {summary['ui']['duration']:.3f}s",
]

logic_areas = sorted(key for key in summary if key.startswith("logic::"))
ui_areas = sorted(key for key in summary if key.startswith("ui::"))
if logic_areas:
    lines.append("- logic areas:")
    for key in logic_areas:
        area = key.split("::", 1)[1]
        lines.append(f"  - {area}: {summary[key]['count']} cases / {summary[key]['duration']:.3f}s")
if ui_areas:
    lines.append("- ui areas:")
    for key in ui_areas:
        area = key.split("::", 1)[1]
        lines.append(f"  - {area}: {summary[key]['count']} cases / {summary[key]['duration']:.3f}s")

for target_kind, title in (("logic", "Logic Tests"), ("ui", "UI Tests")):
    lines.extend(["", f"### {title}"])
    filtered = [record for record in records if record["target_kind"] == target_kind]
    for record in filtered:
        started_at = record["started_at"]
        finished_at = record["finished_at"]
        start_text = started_at.astimezone().strftime("%H:%M:%S") if started_at else "n/a"
        end_text = finished_at.astimezone().strftime("%H:%M:%S") if finished_at else "n/a"
        duration_text = f"{record['duration_seconds']:.3f}s" if record["duration_seconds"] is not None else "n/a"
        lines.append(f"- ID: `{record['unique_id']}`")
        lines.append(f"- 概要: {record['overview']}")
        lines.append(f"- 分類: `{record['target_kind']}` / `{record['area']}`")
        lines.append(f"- ファイル: `{record['file_path']}`")
        lines.append(f"- 開始: `{start_text}`")
        lines.append(f"- 終了: `{end_text}`")
        lines.append(f"- 所要時間: `{duration_text}`")
        lines.append("")

if lines[-1] == "":
    lines.pop()

output_doc.write_text("\n".join(lines) + "\n")
print(f"Updated {output_doc}")
PY

echo "Updated $OUTPUT_DOC"
