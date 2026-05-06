#!/usr/bin/env bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ROOT="${2:-$PROJECT_ROOT}"
PYTHON="$PROJECT_ROOT/.venv/bin/python"
SCRIPT_DIR="$PROJECT_ROOT/inspector"
COMMAND="${1:-collect}"

case "$COMMAND" in
  collect)
    exec "$PYTHON" "$SCRIPT_DIR/collect.py" "$ROOT"
    ;;

  view)
    exec "$PYTHON" "$SCRIPT_DIR/view.py"
    ;;

  *)
    echo "Unknown command: $COMMAND" >&2
    echo "Usage: ./inspector/exec.sh [collect|view] [root]" >&2
    exit 1
    ;;
esac
