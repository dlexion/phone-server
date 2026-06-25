#!/data/data/com.termux/files/usr/bin/bash
# scripts/update-audiobookshelf.sh
# Usage: bash ~/phone-server/scripts/update-audiobookshelf.sh v2.36.0

set -euo pipefail

ABS_VERSION="${1:?Usage: $0 <version e.g. v2.36.0>}"

echo "[INFO] Stopping audiobookshelf service..."
sv stop ~/phone-server/services/audiobookshelf
sleep 3

echo "[INFO] Updating ABS to ${ABS_VERSION} inside Debian..."
proot-distro login debian -- bash -c "
    cd /root/audiobookshelf
    git fetch --tags
    git checkout ${ABS_VERSION}
    npm install --omit=dev 2>&1 | tail -5
"

echo "[INFO] Starting audiobookshelf..."
sv start ~/phone-server/services/audiobookshelf
sleep 5
sv status ~/phone-server/services/audiobookshelf
echo "[SUCCESS] Updated to ${ABS_VERSION}"
