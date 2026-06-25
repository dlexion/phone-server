# 📱 Pixel 3 XL Home Server - AI Context & Architecture

This document serves as the absolute source of truth for the home server architecture running on a Google Pixel 3 XL. AI assistants must read and adhere to these guidelines before suggesting any code, configuration, or architectural changes.

## 1. Hardware & Environment
- **Device:** Google Pixel 3 XL (Snapdragon 845, 4GB RAM).
- **OS:** Android (Rooted) -> Termux (Linux environment). Root access is available if system-level interventions are required.
- **Network:** Connected via Type-C Ethernet Hub + Power Delivery. Tailscale is used as an Exit Node (100.X.Y.Z).
- **Power Management:** Android battery restrictions disabled. `termux-wake-lock` is strictly active to prevent Doze mode and CPU sleep.
- **Process Management:** `runit` daemon is the sole process manager. All services run via individual `run` scripts.

## 2. Architectural Constraints (The "Strict NO" List)
To prevent thermal throttling and ensure 24/7 uptime on an ARM64 Android kernel, the following are strictly prohibited:
- **NO Docker / Containers:** Do not suggest Docker, Docker Compose, Coolify, CasaOS, or Nextcloud.
- **NO Media Transcoding:** Direct Play only. Plex/Jellyfin transcoding is forbidden.
- **NO Heavy Runtimes:** Prefer lightweight native binaries (Go, Rust, C, Python).
- **NO Hardcoded Secrets:** Passwords, tokens, and keys must NEVER be written in code or `*.yml` configs.

## 3. Infrastructure as Code (IaC) & Repository Structure
The system is managed via a centralized Git repository (`~/phone-server`) with symlinks pointing to Termux system paths.

- `/configs/` - Configuration files (e.g., `*.yml`).
- `/scripts/` - Automation and utilities (e.g., `utils.sh`, backups).
- `/services/` - `runit` service definitions (the `run` scripts for app services).
- `/services-meta/` - `runit` meta-services that are supervised by the system-level `runsvdir` (e.g., `phone-services` which wraps `runsvdir` for `/services/`).
- `.secrets/*.env` pattern - Secrets are isolated in gitignored `.env` files.
- **Env Templates:** `configs/env_templates/*.example` serve as the source of truth for variables. Changes must be validated using `scripts/validate_envs.sh`.
- **Templating Fallback:** If a service strictly lacks native env var support, `envsubst` combined with `*.yml.template` files can be used as a workaround in the `run` script.
- **Data Volume Pattern:** All stateful data (SQLite `*.db`, media, user files) is isolated in a dedicated external directory, completely separated from the git codebase for easy backups and SSD migration.
- **Boot Script:** `scripts/boot-init.sh` is the source of truth for the termux:boot script. Deploy with: `cp ~/phone-server/scripts/boot-init.sh ~/.termux/boot/00-system-init.sh`.

## 4. Current Tech Stack
- **Dashboard:** Glance
- **Monitoring:** Beszel (Hub + Agent)
- **Adblock & DNS:** AdGuard Home
- **Notes:** Memos
- **Uptime & Health:** Gatus
- **Seedbox:** qBittorrent-nox (optimized for mobile CPU/RAM).
- **Audiobooks:** Audiobookshelf (Node.js inside Debian proot-distro — avoids android_ndk_path glibc issue; ABS cloned at /root/audiobookshelf inside Debian; server-data bind-mounted at /server-data; books library path inside ABS UI: /server-data/files/audiobooks; update via scripts/update-audiobookshelf.sh; client Nuxt 2 static files built to client/dist/ via install script — required for the UI to load).
- **Custom Scripts:** Qingping Air Monitor (Python script fetching cloud data to `air_data.json`).
- **Reverse Proxy:** Caddy (Handling internal domain routing and static files).
- **Storage:** External SSD + FileBrowser + rclone WebDAV.

## 5. Planned / Upcoming Additions
- Nothing currently planned.

## 6. Process Management Architecture

The system uses a **two-tier runit supervision hierarchy** to ensure all services are automatically restarted even if the inner `runsvdir` is killed by Android's OOM killer:

```
termux:boot → scripts/boot-init.sh → exec runsvdir $PREFIX/var/service
                                           ├── sshd
                                           ├── crond
                                           └── phone-services  ← services-meta/phone-services/run
                                                 └── runsvdir ~/phone-server/services/
                                                       ├── adguard, beszel, caddy...
```

- **`$PREFIX/var/service/phone-services`** is a symlink to `services-meta/phone-services`. It must be created on fresh setup: `ln -sf ~/phone-server/services-meta/phone-services $PREFIX/var/service/phone-services`
- **Finish scripts:** Every service has a `finish` script (`services/<name>/finish`) that kills any lingering process before the next supervised start. This prevents `bind: address already in use` crash-loops that occur when a service process is adopted by init (PPid=1) after an OOM/runsvdir restart and keeps holding its port. Direct Termux-user services use `pkill -x <binary>`; `su -c` wrapped services (adguard, beszel-agent, caddy) use `su -c 'pkill -x <binary>'`.
- **Recovery:** If services still crash-loop after an OOM event (e.g. before finish scripts existed), run `bash ~/phone-server/scripts/recover-services.sh`. This reactively kills init-adopted orphan processes holding ports.

## 7. Development & Coding Guidelines
- **Language:** ALL code, scripts, comments, and logs MUST be in English.
- **Bash Strict Mode:** New scripts should adopt `set -euo pipefail` for fail-fast execution.
- **Early Exit Pattern:** Write linear Bash code. Avoid deep nested `if-else`. Fail fast and log accurately.
- **Modularity:** Source `utils.sh` for repeated tasks like logging or Gatus health-check pings.
- **Cleanup:** Adopt the `trap` command to ensure temporary files or lock files are removed if a script fails or is interrupted.
- **Environment Variables:** Do NOT use the `export` keyword in `.env` files. Sourcing should be done using the `set -a` and `set +a` pattern inside `runit` scripts.
- **Runit `finish` scripts:** Every service that binds a port MUST have a `finish` script. When Android's OOM killer or a crash kills `runsvdir`, the service process is re-parented to init (PPid=1) and survives as an orphan, blocking the port for the next supervised start. The `finish` script is called by runsv on every exit and must kill any such orphan. For `su -c` wrapped services, the root child must be killed via `su -c 'pkill -x <binary>'`.