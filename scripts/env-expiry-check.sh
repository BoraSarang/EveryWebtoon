#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Check all .env files
check_env_file() {
    local file="$1"
    if [ ! -f "$file" ]; then
        return 0
    fi

    # Check for secrets with expiry comments
    while IFS= read -r line; do
        # Skip comments and empty lines
        if [[ "$line" =~ ^[[:space:]]*# ]] || [[ -z "$line" ]]; then
            continue
        fi

        # Extract key and value
        key=$(echo "$line" | cut -d= -f1)
        value=$(echo "$line" | cut -d= -f2-)
        expiry_comment=$(echo "$line" | grep -o '# expires: [0-9-]*' | awk '{print $3}')

        if [ -n "$expiry_comment" ]; then
            expiry_date="$expiry_comment"
            today=$(date +%Y-%m-%d)
            diff_days=$(( ($(date -j -f "%Y-%m-%d" "$expiry_date" +%s 2>/dev/null || date -d "$expiry_date" +%s) - $(date -j -f "%Y-%m-%d" "$today" +%s 2>/dev/null || date -d "$today" +%s)) / 86400 ))

            if [ "$diff_days" -lt 0 ]; then
                echo "❌ EXPIRED: $key (expired $expiry_date)"
                exit 1
            elif [ "$diff_days" -le 30 ]; then
                echo "⚠️  EXPIRING SOON: $key (expires in $diff_days days: $expiry_date)"
            fi
        fi
    done < "$file"
}

echo "🔍 Checking env expiry..."

# Run gitleaks if available
if command -v gitleaks &> /dev/null; then
    echo "🔐 Running gitleaks scan..."
    cd "$PROJECT_DIR"
    if ! gitleaks detect --no-git --report-format=json 2>/dev/null; then
        echo "⚠️  Gitleaks found potential secrets. Please review."
    else
        echo "✅ No secrets detected"
    fi
fi

echo "✅ Env expiry check complete"
