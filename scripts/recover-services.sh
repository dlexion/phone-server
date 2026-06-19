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

# --- Step 2: Kill orphans detected via supervise/pid (runsv not yet restarted) ---
# Handles the case where runsvdir just restarted and supervise/pid still points
# to the old orphaned process whose parent is no longer a runsv.
killed_any=false

for svc_dir in "${SERVICES_DIR}"/*/; do
    svc_name=$(basename "$svc_dir")
    pid_file="${svc_dir}supervise/pid"

    [[ -f "$pid_file" ]] || continue
    svc_pid=$(cat "$pid_file" 2>/dev/null || true)
    [[ -n "$svc_pid" ]] || continue
    kill -0 "$svc_pid" 2>/dev/null || continue

    parent_pid=$(awk '/^PPid:/{print $2}' "/proc/${svc_pid}/status" 2>/dev/null || true)
    [[ -n "$parent_pid" ]] || continue
    parent_name=$(awk '/^Name:/{print $2}' "/proc/${parent_pid}/status" 2>/dev/null || true)

    if [[ "$parent_name" != "runsv" ]]; then
        log_warn "Orphan (pid): ${svc_name} pid=${svc_pid} parent=${parent_pid}(${parent_name}) — killing"
        kill "$svc_pid" 2>/dev/null && log_ok "Killed ${svc_name} (${svc_pid})" || true
        killed_any=true
    fi
done

# --- Step 3: Kill orphans that hold ports of currently-down services ---
# Handles the case where runsv has already restarted (new supervise/pid) but an
# old service process with PPid=1 is still holding the port, causing crash loops.
# We find processes with PPid=1 whose command matches known service binaries.
log_info "Scanning for init-adopted (PPid=1) service processes..."

while IFS= read -r pid; do
    [[ -f "/proc/${pid}/status" ]] || continue
    ppid=$(awk '/^PPid:/{print $2}' "/proc/${pid}/status" 2>/dev/null || true)
    [[ "$ppid" == "1" ]] || continue

    cmdline=$(tr '\0' ' ' < "/proc/${pid}/cmdline" 2>/dev/null || true)
    # Match known service binaries (edit if you add new services)
    case "$cmdline" in
        *memos*|*qbittorrent*|*rclone*|*filebrowser*|*beszel*|*AdGuardHome*|*glance*|*gatus*)
            name=$(awk '/^Name:/{print $2}' "/proc/${pid}/status" 2>/dev/null || true)
            log_warn "Init-orphan detected: pid=${pid} name=${name} — killing"
            kill "$pid" 2>/dev/null && log_ok "Killed orphan ${name} (${pid})" || true
            killed_any=true
            ;;
    esac
done < <(ls /proc | grep -E '^[0-9]+$')

if [[ "$killed_any" == "false" ]]; then
    log_info "No orphaned service processes found."
fi

# --- Step 4: Give runit a moment then print final status ---
sleep 5
echo ""
echo "=== Service status ==="
sv status "${SERVICES_DIR}"/*
