#!/usr/bin/env bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ROOT="${2:-$PROJECT_ROOT}"
PYTHON="$PROJECT_ROOT/.venv/bin/python"
SCRIPT_DIR="$PROJECT_ROOT/inspector"
COMMAND="${1:-all}"
OUTPUT_LOG="$SCRIPT_DIR/output.log"
TMP_OUTPUT_LOG="$SCRIPT_DIR/output.log.tmp.$$"

case "$COMMAND" in
  all)
    "$0" collect "$ROOT" \
      > "$TMP_OUTPUT_LOG" 2>&1
    mv "$TMP_OUTPUT_LOG" "$OUTPUT_LOG"
    ;;

  collect)
    exec "$PYTHON" "$SCRIPT_DIR/collect.py" "$ROOT"
    ;;

  *)
    echo "Unknown command: $COMMAND" >&2
    echo "Usage: ./inspector/exec.sh [all|collect] [root]" >&2
    exit 1
    ;;
esac
