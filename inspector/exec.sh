#!/usr/bin/env bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PYTHON="$PROJECT_ROOT/.venv/bin/python"
SCRIPT_DIR="$PROJECT_ROOT/inspector"
COMMAND="${1:-all}"
DEBUG="${2:-false}"
RAW_BUILD_LOG="$PROJECT_ROOT/llm-temp/xcodebuild-clean-build.log"
SOURCE_FILE="$PROJECT_ROOT/YoutubeFeeder/App/AppConsoleLogger.swift"

print_options() {
  case "$COMMAND" in
    build)
      printf 'options: command=%s\n' "$COMMAND" >&2
      ;;
    collect|all)
      printf 'options: command=%s debug=%s\n' "$COMMAND" "$DEBUG" >&2
      ;;
    *)
      printf 'options: command=%s\n' "$COMMAND" >&2
      ;;
  esac
}

run_step_to_file() {
  local step_name="$1"
  local output_file="$2"
  shift 2
  local start_time end_time status elapsed
  printf '%s start\n' "$step_name" >&2
  start_time=$SECONDS
  set +e
  "$@" > "$output_file" 2>&1
  status=$?
  set -e
  end_time=$SECONDS
  elapsed=$((end_time - start_time))
  printf '%s end elapsed=%ss status=%s\n' "$step_name" "$elapsed" "$status" >&2
  return "$status"
}

validate_debug() {
  case "$DEBUG" in
    true|false) ;;
    *)
      echo "error: debug must be true or false" >&2
      exit 2
      ;;
  esac
}

print_options

if [ "$COMMAND" = build ] && [ $# -gt 1 ]; then
  echo "error: build accepts no debug flag" >&2
  exit 2
fi

case "$COMMAND" in
  collect|all)
    validate_debug
    ;;
esac

case "$COMMAND" in
  all)
    run_step_to_file build "$RAW_BUILD_LOG" "$PYTHON" "$PROJECT_ROOT/scripts/xcode-build/xcodebuild.py" \
      -scheme YoutubeFeeder -configuration Debug -destination platform=macOS CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY= clean build
    run_step_to_file collect "$PROJECT_ROOT/llm-temp/collect.log" "$PYTHON" "$SCRIPT_DIR/collect.py" \
      "$RAW_BUILD_LOG" \
      "$SOURCE_FILE" \
      --debug "$DEBUG"
    # "$0" view
    ;;

  build)
    run_step_to_file build "$RAW_BUILD_LOG" "$PYTHON" "$PROJECT_ROOT/scripts/xcode-build/xcodebuild.py" \
      -scheme YoutubeFeeder -configuration Debug -destination platform=macOS CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY= clean build
    ;;

  collect)
    run_step_to_file collect "$PROJECT_ROOT/llm-temp/collect.log" "$PYTHON" "$SCRIPT_DIR/collect.py" \
      "$RAW_BUILD_LOG" \
      "$SOURCE_FILE" \
      --debug "$DEBUG"
    ;;

  # view)
  #   exec "$PYTHON" "$SCRIPT_DIR/view.py" \
  #     "$SCRIPT_DIR/collect.json" \
  #     > "$SCRIPT_DIR/view.log" 2>&1
  #   ;;

  *)
    echo "Unknown command: $COMMAND" >&2
    echo "Usage: ./inspector/exec.sh [all|build|collect|view] [true|false]" >&2
    exit 1
    ;;
esac
