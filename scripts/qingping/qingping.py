import requests
import json
import time
import os
import sys
import base64
from dotenv import load_dotenv

HOME_DIR = os.getenv("HOME", "/data/data/com.termux/files/home")
SECRETS_FILE = os.path.join(HOME_DIR, "phone-server", ".secrets", "qingping.env")
load_dotenv(SECRETS_FILE)

CLIENT_ID = os.getenv("QINGPING_CLIENT_ID")
CLIENT_SECRET = os.getenv("QINGPING_CLIENT_SECRET")

TOKEN_URL = "https://oauth.cleargrass.com/oauth2/token"
DATA_URL = "https://apis.cleargrass.com/v1/apis/devices"

DATA_DIR = os.path.join(HOME_DIR, "data", "qingping")
PUBLIC_DIR = os.path.join(DATA_DIR, "public")
os.makedirs(PUBLIC_DIR, exist_ok=True)

TOKEN_CACHE_FILE = os.path.join(DATA_DIR, "token_cache.json")
OUTPUT_DATA_FILE = os.path.join(PUBLIC_DIR, "air_data.json")

def get_access_token():
    if os.path.exists(TOKEN_CACHE_FILE):
        try:
            with open(TOKEN_CACHE_FILE, "r") as f:
                cache = json.load(f)
                if time.time() < (cache.get("expires_at", 0) - 60):
                    return cache.get("access_token")
        except Exception as e:
            print(f"Error reading token cache: {e}")

    auth_string = f"{CLIENT_ID}:{CLIENT_SECRET}"
    base64_encoded = base64.b64encode(auth_string.encode('utf-8')).decode('utf-8')
    
    headers = {
        "Authorization": f"Basic {base64_encoded}",
        "Content-Type": "application/x-www-form-urlencoded"
    }

    payload = {
        "grant_type": "client_credentials",
        "scope": "device_full_access"
    }
    
    response = requests.post(TOKEN_URL, headers=headers, data=payload)
    response.raise_for_status() 
    
    token_data = response.json()
    new_token = token_data["access_token"]
    expires_in = token_data.get("expires_in", 7200) 

    cache_data = {
        "access_token": new_token,
        "expires_at": time.time() + expires_in
    }
    with open(TOKEN_CACHE_FILE, "w") as f:
        json.dump(cache_data, f)
        
    return new_token

def fetch_sensor_data(token):
    headers = {"Authorization": f"Bearer {token}"}
    
    current_timestamp = int(time.time() * 1000)
    
    params = {"timestamp": current_timestamp}
    
    response = requests.get(DATA_URL, headers=headers, params=params)
    response.raise_for_status()
    
    data_json = response.json()
    devices = data_json.get("devices", [])
    
    if not devices:
        raise ValueError("No sensors found in server response.")

    device_data = devices[0].get("data", {})
    return device_data

def main():
    try:
        token = get_access_token()
        
        raw_data = fetch_sensor_data(token)

        if not raw_data or "temperature" not in raw_data:
            raise ValueError("API returned empty or invalid data structure")
        
        temp = raw_data.get("temperature", {}).get("value", "N/A")
        co2 = raw_data.get("co2", {}).get("value", "N/A")
        hum = raw_data.get("humidity", {}).get("value", "N/A")
        pm25 = raw_data.get("pm25", {}).get("value", "N/A")
        pm10 = raw_data.get("pm10", {}).get("value", "N/A")

        if temp is None or co2 is None:
             raise ValueError("Essential sensor values are None")
        
        result = {
            "temperature": f"{temp} °C",
            "co2": f"{co2} ppm",
            "humidity": f"{hum} %",
            "pm25": f"{pm25} µg/m³",
            "pm10": f"{pm10} µg/m³",
            "updated": time.strftime("%H:%M")
        }
        
        with open(OUTPUT_DATA_FILE, "w", encoding="utf-8") as f:
            json.dump(result, f, ensure_ascii=False, indent=2)
            
        print(f"[{time.strftime('%H:%M:%S')}] Success: {result}")

    except Exception as e:
        print(f"[{time.strftime('%H:%M:%S')}] Error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()