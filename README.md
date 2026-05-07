# Phone Server Infrastructure (IaC)

This repository contains the Infrastructure as Code (IaC) configuration for a home micro-server running on a repurposed Google Pixel 3 XL (Rooted, LineageOS 22) via Termux. 

The server utilizes `runit` for strict process management, isolates application data, and includes automated, health-checked backups via `rclone` and Gatus.

## 📂 Directory Structure

```text
phone-server/
├── .secrets/           # Git-ignored live environment variables
├── configs/            # Application configuration files (.yaml, .yml)
│   ├── env_templates/  # Source of truth for .env structures
│   ├── gatus/
│   └── glance/
├── scripts/            # Bash utilities, automation, and IoT integrations
│   ├── qingping/       # Qingping API integration & venv
│   ├── backup_memos.sh
│   ├── backup_system.sh
│   └── utils.sh
├── services/           # Runit service daemon files
│   ├── AdGuardHome/
│   ├── beszel/
│   ├── beszel-agent/
│   ├── crond/
│   ├── gatus/
│   ├── glance/
│   ├── memos/
│   ├── qingping/
│   └── sshd/
├── .gitignore
└── README.md
```

## 🛠️ Core Stack

- **Environment:** Termux (Android)
- **Process Manager:** `runit`
- **DNS & AdBlocking:** AdGuard Home
- **Notes:** Memos
- **Dashboard:** Glance
- **System Monitoring:** Beszel (Hub & Agent)
- **Service Health Check:** Gatus
- **IoT Integration:** Qingping Air Monitor Scripts
- **Backups:** Rclone + Cron + SQLite Hot Dumps

## 🚀 Deployment & Restoration

If deploying to a fresh Termux environment or restoring from a crash, follow these steps to link the repository to the system.

1. Clone the repository:
```bash
git clone <repository_url> $HOME/phone-server
```

2. Initialize Secrets:

Create the `.secrets` directory and copy the templates to live `.env` files. **You must edit these new files to fill in your actual secrets.**
```bash
mkdir -p $HOME/phone-server/.secrets

for template in $HOME/phone-server/configs/env_templates/*.example; do
    cp "$template" "$HOME/phone-server/.secrets/$(basename "${template%.example}")"
done

bash $HOME/phone-server/scripts/validate_envs.sh

```

3. Symlink Services (`runit`):

Create absolute symbolic links from the repository to the Termux `$PREFIX/var/service` directory:
> ⚠️ **IMPORTANT:** All scripts must be executable `chmod +x your_script.sh`.
```bash
ln -s $HOME/phone-server/services/memos/run $PREFIX/var/service/memos/run
ln -s $HOME/phone-server/services/gatus/run $PREFIX/var/service/gatus/run
ln -s $HOME/phone-server/services/glance/run $PREFIX/var/service/glance/run
ln -s $HOME/phone-server/services/qingping/run $PREFIX/var/service/qingping/run
ln -s $HOME/phone-server/services/AdGuardHome/run $PREFIX/var/service/AdGuardHome/run
ln -s $HOME/phone-server/services/AdGuardHome/control $PREFIX/var/service/AdGuardHome/control
ln -s $HOME/phone-server/services/sshd/run $PREFIX/var/service/sshd/run
ln -s $HOME/phone-server/services/crond/run $PREFIX/var/service/crond/run
ln -s $HOME/phone-server/services/beszel/run $PREFIX/var/service/beszel/run
ln -s $HOME/phone-server/services/beszel-agent/run $PREFIX/var/service/beszel-agent/run
ln -s $HOME/phone-server/services/caddy/run $PREFIX/var/service/caddy/run
ln -s $HOME/phone-server/services/caddy/control $PREFIX/var/service/caddy/control
```

4. Start the Services:

Once links are created, clear any failed service states and restart runit:
```bash
sv up $PREFIX/var/service/*
```
