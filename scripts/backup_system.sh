#!/data/data/com.termux/files/usr/bin/bash

set -euo pipefail

. "$HOME/phone-server/.secrets/backup.env"
. "$HOME/phone-server/scripts/utils.sh"

SERVICE="system"
TIMESTAMP=$(date +%Y-%m-%d_%H-%M)
ARCHIVE_NAME="system_configs.tar.gz"
TEMP_ARCHIVE_FILE="$TEMP_DIR/$ARCHIVE_NAME"
BACKUP_STAGING_DIR="$TEMP_DIR/system_backup_staging"

cleanup() {
    log_info "Cleaning up temporary files..."
    rm -rf "$BACKUP_STAGING_DIR" "$TEMP_ARCHIVE_FILE"
}
trap cleanup EXIT

log_info "Starting backup for service: $SERVICE"

rm -rf "$BACKUP_STAGING_DIR"
mkdir -p "$BACKUP_STAGING_DIR"

log_info "Exporting system state and configurations..."
pkg list-installed > "$BACKUP_STAGING_DIR/pkg_list.txt"
crontab -l > "$BACKUP_STAGING_DIR/crontab.bak"
termux-info > "$BACKUP_STAGING_DIR/termux_info.txt"

cp -r "$HOME/.termux" "$BACKUP_STAGING_DIR/"
cp -r "$HOME/phone-server/.secrets" "$BACKUP_STAGING_DIR/"
# cp "$HOME/AdGuardHome/AdGuardHome.yaml" "$BACKUP_STAGING_DIR/"

log_info "Creating archive..."
tar -czf "$TEMP_ARCHIVE_FILE" -C "$BACKUP_STAGING_DIR" .
TAR_STATUS=$?

if [ $TAR_STATUS -gt 1 ]; then
    log_err "Error creating archive (code $TAR_STATUS)"
    ping_gatus "maintenance_backup-system" "false" "Tar-failed" "$SYSTEM_BACKUP_TOKEN"
    exit 1
fi

log_info "Uploading to rclone cloud..."
rclone mkdir "$RCLONE_REMOTE:$REMOTE_ROOT/$SERVICE/current/" $RCLONE_OPTS

if rclone copy "$TEMP_ARCHIVE_FILE" "$RCLONE_REMOTE:$REMOTE_ROOT/$SERVICE/current/" \
    --backup-dir "$RCLONE_REMOTE:$REMOTE_ROOT/$SERVICE/archive/$TIMESTAMP/" $RCLONE_OPTS; then
    
    log_info "Backup uploaded successfully!"
    ping_gatus "maintenance_backup-system" "true" "" "$SYSTEM_BACKUP_TOKEN"
    
    rclone delete "$RCLONE_REMOTE:$REMOTE_ROOT/$SERVICE/archive" --min-age "${RETENTION_DAYS}d" $RCLONE_OPTS 2>/dev/null
else
    log_err "rclone upload failed"
    ping_gatus "maintenance_backup-system" "false" "Rclone-failed" "$SYSTEM_BACKUP_TOKEN"
    exit 1
fi

log_info "Script finished."