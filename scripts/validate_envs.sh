#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

REPO_ROOT="$HOME/phone-server"
TEMPLATE_DIR="$REPO_ROOT/configs/env_templates"
SECRETS_DIR="$REPO_ROOT/.secrets"

echo "[INFO] Validating environments..."

ERRORS=0

# Function to extract keys from a file
get_keys() {
    local file="$1"
    # 1. Ignore full-line comments
    # 2. Ignore empty lines
    # 3. Strip 'export ' prefix if present
    # 4. Extract the key (part before '=')
    grep -v '^[[:space:]]*#' "$file" | grep -v '^[[:space:]]*$' | sed 's/^[[:space:]]*export[[:space:]]*//' | cut -d= -f1
}

# Iterate over all live .env files to ensure they are documented and match templates
for env_file in "$SECRETS_DIR"/*.env; do
    [ -e "$env_file" ] || continue
    
    filename=$(basename "$env_file")
    template_file="$TEMPLATE_DIR/${filename}.example"
    
    if [ ! -f "$template_file" ]; then
        echo "[ERROR] Missing template for live environment: $template_file"
        ERRORS=$((ERRORS + 1))
        continue
    fi
    
    # Check if live keys exist in the template (Did you document it?)
    for key in $(get_keys "$env_file"); do
        if ! grep -q "^[[:space:]]*\(export \)\?$key=" "$template_file"; then
            echo "[ERROR] Undocumented key: '$key' is missing from $template_file"
            ERRORS=$((ERRORS + 1))
        fi
    done
    
    # Check if template keys exist in the live file (Did you configure it?)
    for key in $(get_keys "$template_file"); do
        if ! grep -q "^[[:space:]]*\(export \)\?$key=" "$env_file"; then
            echo "[ERROR] Missing live config: '$key' is missing from $env_file (found in template)"
            ERRORS=$((ERRORS + 1))
        fi
    done
done

if [ "$ERRORS" -gt 0 ]; then
    echo "[FAIL] Validation failed with $ERRORS error(s)."
    exit 1
fi

echo "[SUCCESS] All templates and live environments are perfectly synced!"