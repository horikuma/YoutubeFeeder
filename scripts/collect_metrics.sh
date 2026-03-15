#!/bin/zsh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT="$REPO_ROOT/HelloWorld.xcodeproj"
SCHEME="HelloWorld"
DERIVED_DATA="$REPO_ROOT/.DerivedData"
METRICS_DIR="$REPO_ROOT/.metrics"
METRICS_DOC="$REPO_ROOT/metrics.md"
STARTUP_JSON="$METRICS_DIR/startup-metrics.json"
BUILD_LOG="$METRICS_DIR/build-for-testing.log"
TEST_LOG="$METRICS_DIR/test-without-building.log"
DESTINATION="platform=iOS Simulator,name=iPhone 12 mini"
LABEL=""
CHANGE_KIND="source"
MANUAL_RETRIES=0
AUTO_RETRY_LIMIT=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --label)
      LABEL="$2"
      shift 2
      ;;
    --change-kind)
      CHANGE_KIND="$2"
      shift 2
      ;;
    --manual-retries)
      MANUAL_RETRIES="$2"
      shift 2
      ;;
    --auto-retry-limit)
      AUTO_RETRY_LIMIT="$2"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

if [[ -z "$LABEL" ]]; then
  echo "--label is required" >&2
  exit 1
fi

mkdir -p "$METRICS_DIR"
rm -f "$STARTUP_JSON" "$BUILD_LOG" "$TEST_LOG"

now_seconds() {
  python3 - <<'PY'
import time
print(f"{time.time():.6f}")
PY
}

build_start="$(now_seconds)"
xcodebuild build-for-testing \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -destination "$DESTINATION" \
  -derivedDataPath "$DERIVED_DATA" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  >"$BUILD_LOG" 2>&1
build_end="$(now_seconds)"

auto_retries=0
test_status=1

while (( auto_retries <= AUTO_RETRY_LIMIT )); do
  rm -f "$STARTUP_JSON"
  test_start="$(now_seconds)"
  if HELLOWORLD_STARTUP_METRICS_OUTPUT="$STARTUP_JSON" \
    xcodebuild test-without-building \
      -project "$PROJECT" \
      -scheme "$SCHEME" \
      -destination "$DESTINATION" \
      -derivedDataPath "$DERIVED_DATA" \
      CODE_SIGNING_ALLOWED=NO \
      CODE_SIGNING_REQUIRED=NO \
      >"$TEST_LOG" 2>&1; then
    test_end="$(now_seconds)"
    test_status=0
    break
  fi
  test_end="$(now_seconds)"
  (( auto_retries += 1 ))
done

if (( test_status != 0 )); then
  echo "test-without-building failed. See $TEST_LOG" >&2
  exit 1
fi

BUILD_DURATION="$(python3 - <<PY
print(f"{float('$build_end') - float('$build_start'):.3f}")
PY
)"
TEST_DURATION="$(python3 - <<PY
print(f"{float('$test_end') - float('$test_start'):.3f}")
PY
)"
TOTAL_DURATION="$(python3 - <<PY
print(f"{float('$BUILD_DURATION') + float('$TEST_DURATION'):.3f}")
PY
)"
TODAY="$(TZ=Asia/Tokyo date +%Y/%m/%d)"

python3 - "$METRICS_DOC" "$STARTUP_JSON" "$TODAY" "$LABEL" "$CHANGE_KIND" "$DESTINATION" "$BUILD_DURATION" "$TEST_DURATION" "$TOTAL_DURATION" "$MANUAL_RETRIES" "$auto_retries" <<'PY'
import json
import pathlib
import sys

metrics_doc = pathlib.Path(sys.argv[1])
startup_json = pathlib.Path(sys.argv[2])
today = sys.argv[3]
label = sys.argv[4]
change_kind = sys.argv[5]
destination = sys.argv[6]
build_duration = sys.argv[7]
test_duration = sys.argv[8]
total_duration = sys.argv[9]
manual_retries = sys.argv[10]
auto_retries = sys.argv[11]

startup_payload = {}
if startup_json.exists():
    startup_payload = json.loads(startup_json.read_text())
else:
    test_log = startup_json.parent / "test-without-building.log"
    if test_log.exists():
        for line in reversed(test_log.read_text(errors="ignore").splitlines()):
            marker = "HELLOWORLD_STARTUP_METRICS "
            if marker in line:
                startup_payload = json.loads(line.split(marker, 1)[1].strip())
                break

startup_metrics = startup_payload.get("startup_metrics", {})

entry_lines = [
    f"### {label}",
    "",
    f"- 種別: {change_kind}",
    f"- 実行環境: `{destination}`",
]

if change_kind == "source":
    entry_lines.extend(
        [
            f"- build-for-testing: `{build_duration}s`",
            f"- test-without-building: `{test_duration}s`",
            f"- 検証合計時間: `{total_duration}s`",
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
    entry_lines.extend(
        [
            "- 計測: `skip`",
            "- 理由: ドキュメントのみの変更のため",
        ]
    )

entry = "\n".join(entry_lines)
content = metrics_doc.read_text() if metrics_doc.exists() else "# HelloWorld Metrics\n"
heading = f"## {today}"

if heading in content:
    parts = content.split(heading, 1)
    prefix, rest = parts[0], parts[1]
    rest = rest.lstrip("\n")
    updated = f"{prefix}{heading}\n\n{entry}\n\n{rest}"
else:
    if content.endswith("\n"):
        content = content.rstrip("\n")
    updated = f"{content}\n\n{heading}\n\n{entry}\n"

metrics_doc.write_text(updated)
PY

echo "Updated $METRICS_DOC"
echo "build-for-testing: ${BUILD_DURATION}s"
echo "test-without-building: ${TEST_DURATION}s"
echo "verification total: ${TOTAL_DURATION}s"
