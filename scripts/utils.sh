#!/data/data/com.termux/files/usr/bin/sh

log_info() { echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') - $1"; }
log_err() { echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') - $1" >&2; }

ping_gatus() {
    local endpoint="$1"
    local success="$2"
    local error_msg="${3:-}"
    local token="${4:-$SYSTEM_BACKUP_TOKEN}"
    
    local url="$GATUS_API_URL/${endpoint}/external?success=${success}"
    
    if [ -n "$error_msg" ]; then
        url="${url}&error=${error_msg}"
    fi

    curl -X POST "$url" \
         -H "Authorization: Bearer $token" \
         -s -o /dev/null
}