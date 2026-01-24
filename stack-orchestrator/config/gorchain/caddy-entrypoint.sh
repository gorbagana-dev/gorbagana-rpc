#!/bin/sh
set -e

# Source the shared auth snippet generator
. /scripts/generate-auth-snippet.sh

AUTH_SNIPPET="/config/auth.caddyfile"

# Only do API key logic if authentication is enabled
if [ "${API_AUTH_ENABLED}" = "true" ]; then
    API_KEYS_FILE="/data/api_keys"

    # Migrate old single key file to new multi-key format
    OLD_API_KEY_FILE="/data/api_key"
    if [ -f "$OLD_API_KEY_FILE" ] && [ ! -f "$API_KEYS_FILE" ]; then
        echo "Migrating old API key file to new format..."
        mv "$OLD_API_KEY_FILE" "$API_KEYS_FILE"
    fi

    # Generate initial key if no keys exist
    if [ ! -f "$API_KEYS_FILE" ]; then
        echo "==================================================================="
        echo "Generating initial API key for authentication..."
        API_KEY=$(head -c 32 /dev/urandom | hexdump -ve '1/1 "%.2x"')
        echo "$API_KEY" > "$API_KEYS_FILE"
        chmod 600 "$API_KEYS_FILE"
        echo "==================================================================="
        echo "API Key: $API_KEY"
        echo "==================================================================="
        echo "IMPORTANT: Save this key securely"
        echo "The client can authenticate using either:"
        echo "  1. Header (recommended): X-API-Key: <key>"
        echo "  2. Query param: https://yourdomain.com?api_key=<key>"
        echo ""
        echo "To view all keys: laconic-so deployment --dir ./deployment exec caddy \"cat /data/api_keys\""
        echo "To add a new key: laconic-so deployment --dir ./deployment exec caddy \"/scripts/manage-keys.sh add\""
        echo "==================================================================="
    fi

    echo "==================================================================="
    echo "API authentication enabled"
    echo "==================================================================="

    # Generate the auth snippet using shared function
    generate_auth_snippet "$API_KEYS_FILE" "$AUTH_SNIPPET"
else
    # Create empty auth snippet
    echo "" > "$AUTH_SNIPPET"
    echo "API authentication disabled"
fi

# Execute Caddy (replaces this script process with PID 1)
exec /usr/bin/caddy run --config /etc/caddy/Caddyfile --adapter caddyfile
