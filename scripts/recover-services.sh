#!/data/data/com.termux/files/usr/bin/bash
# scripts/recover-services.sh
#
# Use when services show "runsv not running" or are stuck in a crash loop
# after an unexpected runsvdir crash. Detects and kills orphaned processes
# so supervised runsv children can restart them cleanly.
#
# Usage: bash ~/phone-server/scripts/recover-services.sh

set -euo pipefail

SERVICES_DIR="/data/data/com.termux/files/home/phone-server/services"
PHONE_SVC_LINK="/data/data/com.termux/files/usr/var/service/phone-services"

log_info() { echo "[INFO]  $(date '+%H:%M:%S') $*"; }
log_ok()   { echo "[OK]    $(date '+%H:%M:%S') $*"; }
log_warn() { echo "[WARN]  $(date '+%H:%M:%S') $*"; }

# --- Step 1: Ensure runsvdir for phone-server is running ---
if pgrep -f "runsvdir ${SERVICES_DIR}" > /dev/null 2>&1; then
    log_info "runsvdir is alive."
else
    log_warn "runsvdir is NOT running. Restarting via system runit..."
    sv restart "$PHONE_SVC_LINK"
    sleep 5
fi

# --- Step 2 & 3: Delegate to kill-orphans.sh ---
bash /data/data/com.termux/files/home/phone-server/scripts/kill-orphans.sh

# --- Step 4: Give runit a moment then print final status ---
sleep 5
echo ""
echo "=== Service status ==="
sv status "${SERVICES_DIR}"/*
