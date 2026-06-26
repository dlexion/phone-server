#!/data/data/com.termux/files/usr/bin/bash
# scripts/kill-orphans.sh
#
# Detects and kills orphaned processes for phone-server services.
# This script is called automatically before runsvdir starts, and
# can also be used by the manual recovery script.

set -euo pipefail

SERVICES_DIR="/data/data/com.termux/files/home/phone-server/services"

log_info() { echo "[INFO]  $(date '+%H:%M:%S') $*"; }
log_ok()   { echo "[OK]    $(date '+%H:%M:%S') $*"; }
log_warn() { echo "[WARN]  $(date '+%H:%M:%S') $*"; }

killed_any=false

# --- Step 1: Kill orphans detected via supervise/pid (runsv not yet restarted) ---
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
        kill -9 "$svc_pid" 2>/dev/null && log_ok "Killed ${svc_name} (${svc_pid})" || true
        killed_any=true
    fi
done

# --- Step 2: Kill orphans that hold ports of currently-down services ---
log_info "Scanning for init-adopted (PPid=1) service processes..."

while IFS= read -r pid; do
    [[ -f "/proc/${pid}/status" ]] || continue
    ppid=$(awk '/^PPid:/{print $2}' "/proc/${pid}/status" 2>/dev/null || true)
    [[ "$ppid" == "1" ]] || continue

    cmdline=$(tr '\0' ' ' < "/proc/${pid}/cmdline" 2>/dev/null || true)
    # Match known service binaries
    case "$cmdline" in
        *memos*|*qbittorrent*|*rclone*|*filebrowser*|*beszel*|*AdGuardHome*|*glance*|*gatus*)
            name=$(awk '/^Name:/{print $2}' "/proc/${pid}/status" 2>/dev/null || true)
            log_warn "Init-orphan detected: pid=${pid} name=${name} — killing"
            kill -9 "$pid" 2>/dev/null && log_ok "Killed orphan ${name} (${pid})" || true
            killed_any=true
            ;;
    esac
done < <(ls /proc | grep -E '^[0-9]+$')

if [[ "$killed_any" == "false" ]]; then
    log_info "No orphaned service processes found."
fi
