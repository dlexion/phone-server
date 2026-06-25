#!/data/data/com.termux/files/usr/bin/bash
# scripts/install-audiobookshelf.sh — run once on fresh setup
# ABS runs inside a Debian proot-distro container (glibc environment).

set -euo pipefail
ABS_VERSION="v2.35.1"

echo "[INFO] Installing proot-distro if not present..."
pkg install -y proot-distro

echo "[INFO] Installing Debian rootfs if not present..."
proot-distro list | grep -q "^debian" || proot-distro install debian

echo "[INFO] Installing Node.js 20, ffmpeg, git inside Debian..."
proot-distro login debian -- bash -c "
    apt-get update -q
    apt-get install -y curl git ffmpeg
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
    apt-get install -y nodejs
"

echo "[INFO] Cloning and installing ABS ${ABS_VERSION} inside Debian..."
ROOTFS="\$(proot-distro list --json 2>/dev/null | python3 -c \"import json,sys; print([d for d in json.load(sys.stdin) if d.get('name')=='debian'][0]['rootfs'])\" 2>/dev/null || echo /data/data/com.termux/files/usr/var/lib/proot-distro/containers/debian/rootfs)"

cat > "/data/data/com.termux/files/usr/var/lib/proot-distro/containers/debian/rootfs/root/abs-setup.sh" << 'SCRIPTEOF'
#!/bin/bash
set -e
ABS_VERSION="v2.35.1"
if [ ! -d /root/audiobookshelf ]; then
    git clone --depth=1 --branch ${ABS_VERSION} \
        https://github.com/advplyr/audiobookshelf /root/audiobookshelf
fi
cd /root/audiobookshelf
npm_config_logs_max=0 npm install --omit=dev
echo "[INFO] Building client (takes ~5 min)..."
cd client
npm_config_logs_max=0 npm install
npm_config_logs_max=0 npm run generate
echo "[INFO] Done."
SCRIPTEOF
chmod +x /data/data/com.termux/files/usr/var/lib/proot-distro/containers/debian/rootfs/root/abs-setup.sh
proot-distro login debian -- bash /root/abs-setup.sh

echo "[INFO] Creating data directories..."
mkdir -p "$HOME/server-data/data/audiobookshelf/config"
mkdir -p "$HOME/server-data/data/audiobookshelf/metadata"
mkdir -p "$HOME/server-data/files/audiobooks"

echo ""
echo "[SUCCESS] Audiobookshelf installed."
echo "[NEXT]    sv start ~/phone-server/services/audiobookshelf"
echo "[UI]      http://audiobooks.pixel (or http://<tailscale-ip>:13378)"
echo "[NOTE]    Add library path /server-data/files/audiobooks in ABS settings"
