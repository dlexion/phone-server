#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

# Define paths
REPO_ROOT="$HOME/phone-server"
SECRETS_DIR="$REPO_ROOT/.secrets"
TEMPLATE_DIR="$REPO_ROOT/configs/env_templates"

mkdir -p "$TEMPLATE_DIR"

echo "[INFO] Generating safe .env templates..."

# Loop through all real .env files
for env_file in "$SECRETS_DIR"/*.env; do
    [ -e "$env_file" ] || continue 
    
    filename=$(basename "$env_file")
    template_file="$TEMPLATE_DIR/${filename}.example"
    
    # The sed magic: 
    # 1. Keeps comments (#) and empty lines intact.
    # 2. Finds lines with KEY=VALUE and strips everything after '='.
    sed -E 's/^([^#=]+)=.*/\1=/' "$env_file" > "$template_file"
    
    echo "  -> Created template: configs/env_templates/${filename}.example"
done

echo "[SUCCESS] Templates synchronized safely. You can now commit them to Git."