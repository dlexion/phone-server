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
- `/services/` - `runit` service definitions (the `run` scripts).
- `.secrets/*.env` pattern - Secrets are isolated in gitignored `.env` files. 
- **Env Templates:** `configs/env_templates/*.example` serve as the source of truth for variables. Changes must be validated using `scripts/validate_envs.sh`.
- **Templating Fallback:** If a service strictly lacks native env var support, `envsubst` combined with `*.yml.template` files can be used as a workaround in the `run` script.
- **Data Volume Pattern:** All stateful data (SQLite `*.db`, media, user files) is isolated in a dedicated external directory, completely separated from the git codebase for easy backups and SSD migration.

## 4. Current Tech Stack
- **Dashboard:** Glance
- **Monitoring:** Beszel (Hub + Agent)
- **Adblock & DNS:** AdGuard Home
- **Notes:** Memos
- **Uptime & Health:** Gatus
- **Custom Scripts:** Qingping Air Monitor (Python script fetching cloud data to `air_data.json`).

## 5. Planned / Upcoming Additions
- **Reverse Proxy:** Caddy (To replace Python `http.server` for static files and handle internal domain routing).
- **Storage:** External SSD + FileBrowser + rclone WebDAV.
- **Seedbox:** qBittorrent-nox (Strictly optimized for mobile CPU/RAM).

## 6. Development & Coding Guidelines
- **Language:** ALL code, scripts, comments, and logs MUST be in English.
- **Bash Strict Mode:** New scripts should adopt `set -euo pipefail` for fail-fast execution.
- **Early Exit Pattern:** Write linear Bash code. Avoid deep nested `if-else`. Fail fast and log accurately.
- **Modularity:** Source `utils.sh` for repeated tasks like logging or Gatus health-check pings.
- **Cleanup:** Adopt the `trap` command to ensure temporary files or lock files are removed if a script fails or is interrupted.
- **Environment Variables:** Do NOT use the `export` keyword in `.env` files. Sourcing should be done using the `set -a` and `set +a` pattern inside `runit` scripts.