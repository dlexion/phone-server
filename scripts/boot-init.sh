#!/data/data/com.termux/files/usr/bin/bash
# Boot init script for Pixel 3 XL home server.
# Source of truth: ~/phone-server/scripts/boot-init.sh
# Deploy: cp ~/phone-server/scripts/boot-init.sh ~/.termux/boot/00-system-init.sh
#
# Architecture:
#   termux:boot -> this script -> runsvdir $PREFIX/var/service
#                                  ├── sshd
#                                  ├── crond
#                                  └── phone-services  (symlink -> services-meta/phone-services)
#                                        └── runsvdir ~/phone-server/services
#                                              ├── adguard, beszel, caddy, ...

set -euo pipefail

TERMUX_UID="10236"
TERMUX_GID="10236"
MOUNT_POINT="/data/data/com.termux/files/home/server-data"
LOG_DIR="${MOUNT_POINT}/logs"

PHONE_SVC_SRC="/data/data/com.termux/files/home/phone-server/services-meta/phone-services"
PHONE_SVC_LINK="/data/data/com.termux/files/usr/var/service/phone-services"

# --- Wake lock ---
termux-wake-lock

# --- Mount SSD ---
echo "[INFO] Searching for SSD with label server-data..."
DISK_PATH=$(su -c "blkid | grep 'server-data' | cut -d ':' -f 1" || true)

if [[ -z "$DISK_PATH" ]]; then
    echo "[ERROR] Disk 'server-data' not found! Check connection."
    exit 1
fi

echo "[INFO] Disk found at: $DISK_PATH"
echo "[INFO] Setting SELinux to Permissive mode..."
su -c "setenforce 0"

mkdir -p "$MOUNT_POINT"

if su -c "mount | grep -q '$MOUNT_POINT'"; then
    echo "[INFO] Disk already mounted."
else
    echo "[INFO] Mounting disk..."
    su -c "mount -t ext4 -o rw,nosuid,nodev '$DISK_PATH' '$MOUNT_POINT'"
    sleep 1
    echo "[INFO] Transferring ownership to Termux user..."
    su -c "chown -R ${TERMUX_UID}:${TERMUX_GID} '$MOUNT_POINT'"
fi

echo "[SUCCESS] SSD mounted and ready."

# --- Activate Swapfile ---
echo "[INFO] Activating SSD swapfile..."
if su -c "test -f '$MOUNT_POINT/swapfile'"; then
    su -c "swapon '$MOUNT_POINT/swapfile'" || echo "[WARN] Failed to activate swapfile."
else
    echo "[WARN] Swapfile not found at $MOUNT_POINT/swapfile."
fi

# --- Ensure var/service symlink for phone-services exists ---
# The phone-services runit service wraps runsvdir for ~/phone-server/services.
# This means if that runsvdir ever crashes, the system runit auto-restarts it.
if [[ ! -L "$PHONE_SVC_LINK" ]]; then
    echo "[INFO] Creating phone-services symlink in var/service..."
    ln -sf "$PHONE_SVC_SRC" "$PHONE_SVC_LINK"
fi

# --- Source profile and start system runit ---
# shellcheck disable=SC1091
. /data/data/com.termux/files/usr/etc/profile

# --- Disable Android Phantom Process Killer ---
echo "[INFO] Disabling Phantom Process Killer..."
su -c "device_config put activity_manager max_phantom_processes 2147483647" || true
su -c "settings put global settings_enable_monitor_phantom_procs false" || true

mkdir -p "$LOG_DIR"

# Single runsvdir for $PREFIX/var/service.
# It supervises: sshd, crond, and phone-services (which in turn supervises
# all ~/phone-server/services/* via its own nested runsvdir).
exec runsvdir /data/data/com.termux/files/usr/var/service >> "${LOG_DIR}/runit-system.log" 2>&1
