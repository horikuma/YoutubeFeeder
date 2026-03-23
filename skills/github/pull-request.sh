#!/bin/zsh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
VENV_DIR="$REPO_ROOT/.venv"
PYTHON_BIN="$VENV_DIR/bin/python3"
REQUIREMENTS_FILE="$REPO_ROOT/requirements.txt"
STAMP_FILE="$VENV_DIR/.requirements-installed"

if [[ ! -x "$PYTHON_BIN" ]]; then
  python3 -m venv "$VENV_DIR"
fi

if [[ ! -f "$STAMP_FILE" || "$REQUIREMENTS_FILE" -nt "$STAMP_FILE" ]] \
  || ! "$PYTHON_BIN" -c 'import github' >/dev/null 2>&1; then
  PIP_DISABLE_PIP_VERSION_CHECK=1 \
    "$PYTHON_BIN" -m pip install --quiet -r "$REQUIREMENTS_FILE"
  touch "$STAMP_FILE"
fi

PYTHONWARNINGS="ignore" \
  exec "$PYTHON_BIN" "$SCRIPT_DIR/pull-request.py" "$@"
