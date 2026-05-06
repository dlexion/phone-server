#!/data/data/com.termux/files/usr/bin/bash

set -euo pipefail

. "$HOME/phone-server/.secrets/backup.env"
. "$HOME/phone-server/scripts/utils.sh"

SERVICE="memos"
TIMESTAMP=$(date +%Y-%m-%d_%H-%M)
DB_PATH="$HOME/data/memos/memos_prod.db"
TEMP_DB_FILE="$TEMP_DIR/memos_temp.db"
ARCHIVE_NAME="memos_backup.tar.gz"
TEMP_ARCHIVE_FILE="$TEMP_DIR/$ARCHIVE_NAME"

cleanup() {
    log_info "Cleaning up temporary files..."
    rm -f "$TEMP_DB_FILE" "$TEMP_ARCHIVE_FILE"
}
trap cleanup EXIT

log_info "Starting database backup for: $SERVICE"

mkdir -p "$TEMP_DIR"

log_info "Creating SQLite hot dump..."
sqlite3 "$DB_PATH" ".backup '$TEMP_DB_FILE'"

if [ ! -s "$TEMP_DB_FILE" ]; then
    log_err "Error: Dump file not created or is empty!"
    ping_gatus "maintenance_backup-memos" "false" "SQL-Dump-Missing" "$MEMOS_BACKUP_TOKEN"
    exit 1
fi

log_info "Archiving dump..."
tar -czf "$TEMP_ARCHIVE_FILE" -C "$TEMP_DIR" "$(basename "$TEMP_DB_FILE")"
TAR_STATUS=$?

if [ $TAR_STATUS -gt 1 ]; then
    log_err "Error creating archive (code $TAR_STATUS)"
    ping_gatus "maintenance_backup-memos" "false" "Tar-failed" "$MEMOS_BACKUP_TOKEN"
    exit 1
fi

log_info "Uploading to rclone cloud..."
rclone mkdir "$RCLONE_REMOTE:$REMOTE_ROOT/$SERVICE/current/" $RCLONE_OPTS

if rclone copy "$TEMP_ARCHIVE_FILE" "$RCLONE_REMOTE:$REMOTE_ROOT/$SERVICE/current/" \
    --backup-dir "$RCLONE_REMOTE:$REMOTE_ROOT/$SERVICE/archive/$TIMESTAMP/" $RCLONE_OPTS; then
    
    log_info "Backup uploaded successfully!"
    ping_gatus "maintenance_backup-memos" "true" "" "$MEMOS_BACKUP_TOKEN"
    
    rclone delete "$RCLONE_REMOTE:$REMOTE_ROOT/$SERVICE/archive" --min-age "${RETENTION_DAYS}d" $RCLONE_OPTS 2>/dev/null
else
    log_err "rclone upload failed"
    ping_gatus "maintenance_backup-memos" "false" "Rclone-failed" "$MEMOS_BACKUP_TOKEN"
    exit 1
fi

log_info "Script finished."