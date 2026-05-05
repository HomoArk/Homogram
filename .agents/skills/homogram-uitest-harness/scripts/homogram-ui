#!/usr/bin/env sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

if command -v uv >/dev/null 2>&1; then
  exec uv run python "$SCRIPT_DIR/homogram_ui_harness.py" "$@"
fi

if command -v python3 >/dev/null 2>&1; then
  exec python3 "$SCRIPT_DIR/homogram_ui_harness.py" "$@"
fi

exec python "$SCRIPT_DIR/homogram_ui_harness.py" "$@"
