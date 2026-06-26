# Phone Server Infrastructure (IaC)

This repository contains the Infrastructure as Code (IaC) configuration for a home micro-server running on a repurposed Google Pixel 3 XL (Rooted, LineageOS 22) via Termux. 

The server utilizes `runit` for strict process management, isolates application data, and includes automated, health-checked backups via `rclone` and Gatus.

## 📂 Directory Structure

```text
phone-server/
├── .secrets/           # Git-ignored live environment variables
├── configs/            # Application configuration files (.yaml, .yml)
│   ├── caddy/
│   ├── env_templates/  # Source of truth for .env structures
│   ├── gatus/
│   └── glance/
├── scripts/            # Bash utilities, automation, and IoT integrations
│   ├── qingping/       # Qingping API integration & venv
│   ├── boot-init.sh    # Source of truth for termux:boot startup script (activates swapfile)
│   ├── kill-orphans.sh # Proactively kills orphaned ports on runsvdir restart
│   ├── recover-services.sh  # Manual fallback for orphan process cleanup
│   ├── backup_memos.sh
│   ├── backup_system.sh
│   └── utils.sh
├── services/           # Runit app service definitions (run scripts)
│   ├── adguard/        # includes finish script (root process cleanup)
│   ├── beszel/
│   ├── beszel-agent/
│   ├── caddy/
│   ├── filebrowser/
│   ├── gatus/
│   ├── glance/
│   ├── memos/
│   ├── qbittorrent/
│   └── webdav/
├── services-meta/      # Runit meta-services (supervised by system runsvdir)
│   └── phone-services/ # Wraps runsvdir for services/ — enables auto-recovery
├── .gitignore
└── README.md
```

## 🛠️ Core Stack

- **Environment:** Termux (Android)
- **Process Manager:** `runit` (two-tier supervision hierarchy)
- **DNS & AdBlocking:** AdGuard Home
- **Notes:** Memos
- **Dashboard:** Glance
- **System Monitoring:** Beszel (Hub & Agent)
- **Service Health Check:** Gatus (Monitors health of all active services)
- **Seedbox:** qBittorrent-nox
- **IoT Integration:** Qingping Air Monitor Scripts
- **Backups:** Rclone + Cron + SQLite Hot Dumps
- **Reverse Proxy:** Caddy
- **Storage:** FileBrowser & rclone WebDAV

## 🚀 Deployment & Restoration

If deploying to a fresh Termux environment or restoring from a crash, follow these steps.

1. **Clone the repository:**
```bash
git clone <repository_url> $HOME/phone-server
```

2. **Initialize secrets:**

Create `.secrets/` and populate from templates. **Edit each file to fill in actual values.**
```bash
mkdir -p $HOME/phone-server/.secrets
for template in $HOME/phone-server/configs/env_templates/*.example; do
    cp "$template" "$HOME/phone-server/.secrets/$(basename "${template%.example}")"
done
bash $HOME/phone-server/scripts/validate_envs.sh
```

3. **Wire up the system runit meta-service:**

This symlink makes the system-level `runsvdir` supervise your app services, so they auto-recover even after an OOM kill.
```bash
ln -sf $HOME/phone-server/services-meta/phone-services \
       $PREFIX/var/service/phone-services
```

4. **Deploy the boot script:**
```bash
cp $HOME/phone-server/scripts/boot-init.sh ~/.termux/boot/00-system-init.sh
chmod +x ~/.termux/boot/00-system-init.sh
```

5. **Reboot or start manually:**
```bash
# Or start without rebooting:
bash ~/.termux/boot/00-system-init.sh
```

> ⚠️ All scripts must be executable: `chmod +x <script>`

## 🔧 Recovery

**Note on OOM Kills:** The system is configured with a massive SSD swapfile to prevent Android's OOM killer from terminating services. If an OOM event does occur, the `phone-services` supervisor automatically runs `kill-orphans.sh` on restart to gracefully clear out orphaned ports.

If services show `runsv not running` or you need to manually force an orphan cleanup:
```bash
bash ~/phone-server/scripts/recover-services.sh
```

For a normal supervised restart of all app services:
```bash
sv restart $PREFIX/var/service/phone-services
```