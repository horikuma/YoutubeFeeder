#!/usr/bin/env bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PYTHON="$PROJECT_ROOT/.venv/bin/python"
SCRIPT_DIR="$PROJECT_ROOT/inspector"
COMMAND="${1:-all}"

case "$COMMAND" in
  all)
    "$0" collect
    # "$0" view
    ;;

  build)
    exec "$PYTHON" "$PROJECT_ROOT/scripts/xcode-build/xcodebuild.py" \
      -scheme YoutubeFeeder -configuration Debug -destination platform=macOS CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY= clean build \
      > "$PROJECT_ROOT/llm-temp/xcodebuild-clean-build.log" 2>&1
    ;;

  extract)
    exec "$PYTHON" "$SCRIPT_DIR/extract.py" \
      "$PROJECT_ROOT/llm-temp/xcodebuild-clean-build.log" \
      > /dev/null 2>&1
    ;;

  collect)
    exec "$PYTHON" "$SCRIPT_DIR/collect.py" \
      "$PROJECT_ROOT/YoutubeFeeder/App/AppConsoleLogger.swift" \
      > "$PROJECT_ROOT/llm-temp/collect.log" 2>&1
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
