#!/bin/zsh

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
VENV_DIR="$SCRIPT_DIR/.venv"
PYTHON_BIN="$VENV_DIR/bin/python3"

if [[ ! -x "$PYTHON_BIN" ]]; then
  python3 -m venv "$VENV_DIR"
fi

"$PYTHON_BIN" -m pip install --quiet --disable-pip-version-check -r "$SCRIPT_DIR/requirements.txt"
PYTHONWARNINGS="ignore" "$PYTHON_BIN" "$SCRIPT_DIR/pull-request.py" "$@"
