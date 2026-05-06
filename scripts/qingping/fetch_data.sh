#!/data/data/com.termux/files/usr/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VENV_DIR="$SCRIPT_DIR/venv"
PYTHON_SCRIPT="$SCRIPT_DIR/qingping.py"

. "$HOME/phone-server/.secrets/boot.env"
. "$HOME/phone-server/.secrets/qingping.env"
. "$HOME/phone-server/scripts/utils.sh"

cleanup() {
    # Cleanup tasks can be added here
    :
}
trap cleanup EXIT

if [ ! -d "$VENV_DIR" ]; then
    log_err "Error: Virtual environment not found at $VENV_DIR"
    ping_gatus "iot_qingping" "false" "Venv-Missing" "${QINGPING_GATUS_TOKEN:-}"
    exit 1
fi

if "$VENV_DIR/bin/python" "$PYTHON_SCRIPT"; then
    ping_gatus "iot_qingping" "true" "" "${QINGPING_GATUS_TOKEN:-}"
else
    ping_gatus "iot_qingping" "false" "Python-Script-Failed" "${QINGPING_GATUS_TOKEN:-}"
    exit 1
fi