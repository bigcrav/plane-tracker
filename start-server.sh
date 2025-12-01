#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="$ROOT_DIR/.venv"
REQ_FILE="$ROOT_DIR/macos-widget/requirements-macos.txt"

# Allow overrides: INTERVAL (seconds), HOST, PORT, and SKIP_INSTALL=1 to skip pip.
INTERVAL="${INTERVAL:-180}"
HOST="${HOST:-0.0.0.0}"
PORT="${PORT:-8080}"

if [ ! -d "$VENV_DIR" ]; then
  python3 -m venv "$VENV_DIR"
fi

# shellcheck disable=SC1091
source "$VENV_DIR/bin/activate"

if [ "${SKIP_INSTALL:-0}" != "1" ]; then
  pip install --upgrade pip
  pip install -r "$REQ_FILE"
fi

exec python "$ROOT_DIR/server/run_server.py" --interval "$INTERVAL" --host "$HOST" --port "$PORT" "$@"
