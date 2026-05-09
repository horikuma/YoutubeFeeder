#!/usr/bin/env bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PYTHON="$PROJECT_ROOT/.venv/bin/python"
SCRIPT_DIR="$PROJECT_ROOT/inspector"
COMMAND="${1:-all}"

case "$COMMAND" in
  all)
    "$0" collect
    "$0" view
    ;;

  collect)
    exec "$PYTHON" "$SCRIPT_DIR/collect.py" \
      "../YoutubeFeeder/YoutubeFeeder/App/AppConsoleLogger.swift" \
      > "$SCRIPT_DIR/collect.log" 2>&1
    ;;

  # view)
  #   exec "$PYTHON" "$SCRIPT_DIR/view.py" \
  #     "$SCRIPT_DIR/collect.json" \
  #     > "$SCRIPT_DIR/view.log" 2>&1
  #   ;;

  *)
    echo "Unknown command: $COMMAND" >&2
    echo "Usage: ./inspector/exec.sh [all|collect|view]" >&2
    exit 1
    ;;
esac
