#!/data/data/com.termux/files/usr/bin/sh

set -u

. $HOME/backups/config.env
. $HOME/backups/scripts/utils.sh

SERVICE="system"
TIMESTAMP=$(date +%Y-%m-%d_%H-%M)
ARCHIVE_NAME="system_configs.tar.gz"

log_info "Starting backup for service: $SERVICE"

mkdir -p "$TEMP_DIR"

log_info "Exporting system data..."
pkg list-installed > "$TEMP_DIR/pkg_list.txt"
crontab -l > "$TEMP_DIR/crontab.bak"
termux-info > "$TEMP_DIR/termux_info.txt"

# TODO: problem with user access (captured by root user)
su -c "cat $HOME/AdGuardHome/AdGuardHome.yaml" > "$TEMP_DIR/AdGuardHome.yaml" 2>/dev/null 

# TODO: simlins not saved correctly
log_info "Creating archive $ARCHIVE_NAME..."
tar -czf "$TEMP_DIR/$ARCHIVE_NAME" \
    -C "$HOME" ".termux" \
    -C "$HOME" "boot.env" \
    -C "$HOME/backups" "config.env" \
    -C "$HOME/backups" "scripts" \
    -C "$HOME/gatus" "config.yaml" \
    -C "$HOME/glance" "glance.yml" \
    -C "$PREFIX/var" "service" \
    -C "$TEMP_DIR" "AdGuardHome.yaml" \
    -C "$TEMP_DIR" "pkg_list.txt" \
    -C "$TEMP_DIR" "crontab.bak" \
    -C "$TEMP_DIR" "termux_info.txt"

TAR_STATUS=$?

if [ $TAR_STATUS -gt 1 ]; then
    log_err "Error creating archive (code $TAR_STATUS)"
    ping_gatus "maintenance_backup-system" "false" "Tar-failed"
    
    rm -f "$TEMP_DIR/pkg_list.txt" "$TEMP_DIR/crontab.bak" "$TEMP_DIR/termux_info.txt" "$TEMP_DIR/$ARCHIVE_NAME"
    exit 1
fi

log_info "Uploading to rclone cloud..."
rclone mkdir "$RCLONE_REMOTE:$REMOTE_ROOT/$SERVICE/current/" $RCLONE_OPTS

if rclone copy "$TEMP_DIR/$ARCHIVE_NAME" "$RCLONE_REMOTE:$REMOTE_ROOT/$SERVICE/current/" \
    --backup-dir "$RCLONE_REMOTE:$REMOTE_ROOT/$SERVICE/archive/$TIMESTAMP/" $RCLONE_OPTS; then
    
    log_info "Backup uploaded successfully!"
    ping_gatus "maintenance_backup-system" "true"
    
    rclone delete "$RCLONE_REMOTE:$REMOTE_ROOT/$SERVICE/archive" --min-age "${RETENTION_DAYS}d" $RCLONE_OPTS 2>/dev/null
else
    log_err "rclone upload failed"
    ping_gatus "maintenance_backup-system" "false" "Rclone-failed"
fi

log_info "Cleaning up temporary files..."
rm -f "$TEMP_DIR/$ARCHIVE_NAME" \
      "$TEMP_DIR/AdGuardHome.yaml" \
      "$TEMP_DIR/pkg_list.txt" \
      "$TEMP_DIR/crontab.bak" \
      "$TEMP_DIR/termux_info.txt"

log_info "Script finished."