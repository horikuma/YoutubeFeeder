#!/bin/zsh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT="$REPO_ROOT/YoutubeFeeder.xcodeproj"
SCHEME="YoutubeFeeder"
DERIVED_DATA_BASE="${HOME}/Library/Caches/Codex/YoutubeFeeder"
DERIVED_DATA="$DERIVED_DATA_BASE/DerivedData"
DESTINATION="platform=iOS Simulator,name=iPhone 12 mini"
DEVICE_NAME="iPhone 12 mini"
TEMP_LLM_DIR="$REPO_ROOT/temp-llm"
RUN_STAMP="$(date +%Y%m%d-%H%M%S)"
TMP_METRICS_DIR="$TEMP_LLM_DIR/collect-test-metrics-$RUN_STAMP"
BUILD_LOG="$TEMP_LLM_DIR/collect-test-metrics-build-$RUN_STAMP.log"
UNIT_LOG="$TEMP_LLM_DIR/collect-test-metrics-unit-$RUN_STAMP.log"
UI_LOG="$TEMP_LLM_DIR/collect-test-metrics-ui-$RUN_STAMP.log"
OUTPUT_DOC="$REPO_ROOT/docs/test-metrics.md"
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

mkdir -p "$TEMP_LLM_DIR"
mkdir -p "$DERIVED_DATA_BASE"
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
  >"$BUILD_LOG" 2>&1

echo "Running unit tests..."
unit_args=("-only-testing:YoutubeFeederTests")
if (( ${#LOGIC_ONLY_TESTING[@]} > 0 )); then
  unit_args=()
  for test_id in "${LOGIC_ONLY_TESTING[@]}"; do
    unit_args+=("-only-testing:${test_id}")
  done
fi
YOUTUBEFEEDER_TEST_METRICS_DIR="$TMP_METRICS_DIR" xcodebuild test-without-building \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -destination "$DESTINATION" \
  -derivedDataPath "$DERIVED_DATA" \
  "${unit_args[@]}" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  >"$UNIT_LOG" 2>&1

echo "Running UI tests..."
ui_args=("-only-testing:YoutubeFeederUITests")
if (( ${#UI_ONLY_TESTING[@]} > 0 )); then
  ui_args=()
  for test_id in "${UI_ONLY_TESTING[@]}"; do
    ui_args+=("-only-testing:${test_id}")
  done
fi
YOUTUBEFEEDER_TEST_METRICS_DIR="$TMP_METRICS_DIR" xcodebuild test-without-building \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -destination "$DESTINATION" \
  -derivedDataPath "$DERIVED_DATA" \
  "${ui_args[@]}" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  >"$UI_LOG" 2>&1

python3 "$SCRIPT_DIR/render_test_metrics.py" \
  "$REPO_ROOT" \
  "$OUTPUT_DOC" \
  "$UNIT_LOG" \
  "$UI_LOG"
