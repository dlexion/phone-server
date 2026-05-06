# Qingping Air Monitor Integration

This directory contains the automation scripts for fetching sensor data (Temperature, CO2, Humidity, PM2.5, PM10) from the Cleargrass (Qingping) Cloud API.

## 📄 Files Overview

- `qingping.py`: The core Python script. It handles OAuth2 token fetching, caching, and querying the API.
- `fetch_data.sh`: A strict Bash wrapper script (`set -euo pipefail`) designed for `crond`. It ensures the Python script is executed securely within its isolated virtual environment.
- `requirements.txt`: Dependencies for the Python script.

## ⚙️ Setup Instructions

### 1. Virtual Environment
Create an isolated Python virtual environment and install dependencies:
```bash
cd ~/phone-server/scripts/qingping
python -m venv venv
venv/bin/pip install -r requirements.txt
chmod +x fetch_data.sh
```

### 2. Secrets Configuration
Do **not** place secrets in this directory. Create the `.env` file at the system-designated path:
`~/phone-server/.secrets/qingping.env`

Add the following variables:
```env
QINGPING_CLIENT_ID="your_client_id"
QINGPING_CLIENT_SECRET="your_client_secret"
QINGPING_GATUS_TOKEN="your_gatus_token_here_if_using_auth" # Optional
```

### 3. Crond Automation
To run this script automatically (e.g., every 20 minutes), add the following to your crontab (`crontab -e`):
```cron
*/20 * * * * /data/data/com.termux/files/home/phone-server/scripts/qingping/fetch_data.sh >> /data/data/com.termux/files/home/logs/qingping.log 2>&1
```

## 📂 Data Storage
Following the home server architecture, stateful data is saved outside the git repository:
- **Token Cache:** `~/data/qingping/token_cache.json`
- **Public Output:** `~/data/qingping/public/air_data.json` (Targeted for dashboards or a static web server).