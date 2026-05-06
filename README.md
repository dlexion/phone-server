# Phone Server Infrastructure (IaC)

This repository contains the Infrastructure as Code (IaC) configuration for a home micro-server running on a repurposed Google Pixel 3 XL (Rooted, LineageOS 22) via Termux. 

The server utilizes `runit` for strict process management, isolates application data, and includes automated, health-checked backups via `rclone` and Gatus.

## 📂 Directory Structure

```text
phone-server/
├── configs/            # Application configuration files (.yaml, .yml)
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

> ⚠️ **IMPORTANT:** All symbolic links (`ln -s`) must be created from inside the Termux shell (e.g. ssh).

1. Clone the repository:
```bash
git clone <repository_url> $HOME/phone-server
```

2. Restore Environment Secrets:

Ensure your config.env and boot.env files are securely restored to their respective directories (e.g., `$HOME/backups/config.env`) outside of this repository.

3. Symlink Services (`runit`):

Create absolute symbolic links from the repository to the Termux `$PREFIX/var/service` directory:
```bash
ln -s $HOME/phone-server/services/memos/run $PREFIX/var/service/memos/run
ln -s $HOME/phone-server/services/gatus/run $PREFIX/var/service/gatus/run
ln -s $HOME/phone-server/services/glance/run $PREFIX/var/service/glance/run
ln -s $HOME/phone-server/services/qingping/run $PREFIX/var/service/qingping/run
ln -s $HOME/phone-server/services/AdGuardHome/run $PREFIX/var/service/AdGuardHome/run
ln -s $HOME/phone-server/services/sshd/run $PREFIX/var/service/sshd/run
ln -s $HOME/phone-server/services/crond/run $PREFIX/var/service/crond/run
ln -s $HOME/phone-server/services/beszel/run $PREFIX/var/service/beszel/run
ln -s $HOME/phone-server/services/beszel-agent/run $PREFIX/var/service/beszel-agent/run
```

4. Start the Services:

Once links are created, clear any failed service states and restart runit:
```bash
sv up $PREFIX/var/service/*
```
