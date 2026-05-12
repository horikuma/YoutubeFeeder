#!/usr/bin/env bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PYTHON="$PROJECT_ROOT/.venv/bin/python"
SCRIPT_DIR="$PROJECT_ROOT/inspector"
VIEWS_DIR="$SCRIPT_DIR/views"
COMMAND="${1:-all}"
ARG2="${2:-}"
ARG3="${3:-}"
DEBUG="false"
COLLECT_DB_PATH="$PROJECT_ROOT/llm-cache/collect.db"
RAW_BUILD_LOG="$PROJECT_ROOT/llm-temp/xcodebuild.log"
SOURCE_ROOT="$PROJECT_ROOT/YoutubeFeeder/App/Support/AppTestSupport.swift"

case "$COMMAND" in
  funcs|vars|edges)
    if [ -n "$ARG2" ]; then
      COLLECT_DB_PATH="$ARG2"
    fi
    ;;
  build|collect|all)
    if [ -n "$ARG2" ]; then
      DEBUG="$ARG2"
    fi
    if [ -n "$ARG3" ]; then
      COLLECT_DB_PATH="$ARG3"
    fi
    ;;
esac

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

run_step_to_stdout_file() {
  local step_name="$1"
  local output_file="$2"
  shift 2
  local start_time end_time status elapsed
  printf '%s start\n' "$step_name" >&2
  start_time=$SECONDS
  set +e
  "$@" > "$output_file"
  status=$?
  set -e
  end_time=$SECONDS
  elapsed=$((end_time - start_time))
  printf '%s end elapsed=%ss status=%s\n' "$step_name" "$elapsed" "$status" >&2
  return "$status"
}

printf 'options: command=%s debug=%s\n' "$COMMAND" "$DEBUG" >&2
if [ "$COMMAND" = funcs ] || [ "$COMMAND" = vars ] || [ "$COMMAND" = edges ]; then
  printf 'options: command=%s db=%s\n' "$COMMAND" "$COLLECT_DB_PATH" >&2
fi

case "$COMMAND" in
  all)
    "$0" build
    "$0" collect "$DEBUG"
    "$0" funcs "$COLLECT_DB_PATH"
    "$0" vars "$COLLECT_DB_PATH"
    "$0" edges "$COLLECT_DB_PATH"
    ;;

  build)
    run_step_to_file build "$RAW_BUILD_LOG" \
      "$PYTHON" "$PROJECT_ROOT/scripts/xcode-build/xcodebuild.py" \
        -scheme YoutubeFeeder \
        -configuration Debug \
        -destination platform=macOS \
        CODE_SIGNING_ALLOWED=NO \
        CODE_SIGNING_REQUIRED=NO \
        CODE_SIGN_IDENTITY= \
        clean \
        build
    ;;

  collect)
    run_step_to_file collect "$PROJECT_ROOT/llm-temp/collect.log" \
      "$PYTHON" "$SCRIPT_DIR/collect.py" \
        "$RAW_BUILD_LOG" \
        "$SOURCE_ROOT" \
        --debug "$DEBUG"
    ;;

  funcs)
    run_step_to_stdout_file funcs "$PROJECT_ROOT/llm-temp/funcs.log" \
      "$PYTHON" "$VIEWS_DIR/functions.py" \
        "$COLLECT_DB_PATH"
    ;;

  vars)
    run_step_to_stdout_file vars "$PROJECT_ROOT/llm-temp/vars.log" \
      "$PYTHON" "$VIEWS_DIR/variables.py" \
        "$COLLECT_DB_PATH"
    ;;

  edges)
    run_step_to_stdout_file edges "$PROJECT_ROOT/llm-temp/edges.log" \
      "$PYTHON" "$VIEWS_DIR/edges.py" \
        "$COLLECT_DB_PATH"
    ;;

  *)
    echo "Unknown command: $COMMAND" >&2
    echo "Usage: ./inspector/exec.sh [all|build|collect|funcs|vars|edges] [debug=true|false] [collect.db path]" >&2
    exit 1
    ;;
esac
