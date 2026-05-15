#!/usr/bin/env bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PYTHON="$PROJECT_ROOT/.venv/bin/python"
SCRIPT_DIR="$PROJECT_ROOT/inspector"
VIEWS_DIR="$SCRIPT_DIR/views"
COMMAND="${1:-all}"
ARG2="${2:-}"
ARG3="${3:-}"
ARG4="${4:-}"
COLLECT_DB_PATH="$PROJECT_ROOT/llm-cache/collect.db"
SOURCE_ROOT="$PROJECT_ROOT/YoutubeFeeder"
OUTPUT_DIR="$PROJECT_ROOT/llm-temp"
CALL_GRAPH_PATH="$PROJECT_ROOT/llm-temp/call-graph.yaml"

case "$COMMAND" in
  funcs|vars|edges|call-graph)
    if [ -n "$ARG2" ]; then
      COLLECT_DB_PATH="$ARG2"
    fi
    if [ -n "$ARG3" ]; then
      SOURCE_ROOT="$ARG3"
    fi
    if [ -n "$ARG4" ]; then
      CALL_GRAPH_PATH="$ARG4"
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

mkdir -p "$OUTPUT_DIR"

printf 'options: command=%s db=%s source=%s output=%s\n' \
  "$COMMAND" "$COLLECT_DB_PATH" "$SOURCE_ROOT" "$CALL_GRAPH_PATH" >&2

case "$COMMAND" in
  all)
    "$0" funcs "$COLLECT_DB_PATH" "$SOURCE_ROOT" "$CALL_GRAPH_PATH"
    "$0" vars "$COLLECT_DB_PATH" "$SOURCE_ROOT" "$CALL_GRAPH_PATH"
    "$0" edges "$COLLECT_DB_PATH" "$SOURCE_ROOT" "$CALL_GRAPH_PATH"
    "$0" call-graph "$COLLECT_DB_PATH" "$SOURCE_ROOT" "$CALL_GRAPH_PATH"
    ;;

  funcs)
    run_step_to_stdout_file funcs "$OUTPUT_DIR/funcs.log" \
      "$PYTHON" "$VIEWS_DIR/functions.py" \
        "$COLLECT_DB_PATH"
    ;;

  vars)
    run_step_to_stdout_file vars "$OUTPUT_DIR/vars.log" \
      "$PYTHON" "$VIEWS_DIR/variables.py" \
        "$COLLECT_DB_PATH"
    ;;

  edges)
    run_step_to_stdout_file edges "$OUTPUT_DIR/edges.log" \
      "$PYTHON" "$VIEWS_DIR/edges.py" \
        "$COLLECT_DB_PATH" \
        --source-root "$SOURCE_ROOT"
    ;;

  call-graph)
    run_step_to_stdout_file call-graph "$CALL_GRAPH_PATH" \
      "$PYTHON" "$VIEWS_DIR/edges.py" \
        "$COLLECT_DB_PATH" \
        --source-root "$SOURCE_ROOT" \
        --call-graph
    ;;

  *)
    echo "Unknown command: $COMMAND" >&2
    echo "Usage: ./inspector/views.sh [all|funcs|vars|edges|call-graph] [collect.db path] [source-root path] [call-graph path]" >&2
    exit 1
    ;;
esac
