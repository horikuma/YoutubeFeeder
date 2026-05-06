#!/usr/bin/env bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ROOT="${2:-$PROJECT_ROOT}"
PYTHON="$PROJECT_ROOT/.venv/bin/python"
SCRIPT_DIR="$PROJECT_ROOT/inspector"
COMMAND="${1:-all}"
OUTPUT_LOG="$SCRIPT_DIR/output.log"

case "$COMMAND" in
  all)
    "$0" collect "$ROOT" \
      > "$OUTPUT_LOG" 2>&1

    "$0" view "$ROOT" \
      >> "$OUTPUT_LOG" 2>&1
    ;;

  collect)
    exec "$PYTHON" "$SCRIPT_DIR/collect.py" "$ROOT"
    ;;

  view)
    "$PYTHON" "$SCRIPT_DIR/view_summary.py"
    "$PYTHON" "$SCRIPT_DIR/view_architecture.py"
    "$PYTHON" "$SCRIPT_DIR/view_graph_health.py"
    exec "$PYTHON" "$SCRIPT_DIR/view_identity.py"
    ;;

  *)
    echo "Unknown command: $COMMAND" >&2
    echo "Usage: ./inspector/exec.sh [all|collect|view] [root]" >&2
    exit 1
    ;;
esac
