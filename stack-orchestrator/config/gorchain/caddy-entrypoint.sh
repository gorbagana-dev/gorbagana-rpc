#!/bin/sh
set -e

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

    # Read all keys and export as environment variables
    KEY_INDEX=1
    while IFS= read -r key || [ -n "$key" ]; do
        # Skip empty lines and comments
        if [ -n "$key" ] && [ "${key#\#}" = "$key" ]; then
            export "API_KEY_${KEY_INDEX}=$key"
            KEY_INDEX=$((KEY_INDEX + 1))
        fi
    done < "$API_KEYS_FILE"

    TOTAL_KEYS=$((KEY_INDEX - 1))

    echo "==================================================================="
    echo "API authentication enabled with $TOTAL_KEYS key(s)"
    echo "==================================================================="

    # Build the auth expression dynamically
    AUTH_EXPR=""
    for i in $(seq 1 $TOTAL_KEYS); do
        if [ -n "$AUTH_EXPR" ]; then
            AUTH_EXPR="$AUTH_EXPR || "
        fi
        AUTH_EXPR="${AUTH_EXPR}{header.X-API-Key} == {env.API_KEY_${i}} || {query.api_key} == {env.API_KEY_${i}}"
    done

    # Create auth snippet based on whether auth is optional or required
    if [ "${API_AUTH_OPTIONAL}" = "true" ]; then
        # Optional mode: if key is provided, validate it; if not provided, allow through
        cat > "$AUTH_SNIPPET" <<EOF
# Optional auth: allow no key, but validate if provided
@invalid_key expression \`({header.X-API-Key} != "" || {query.api_key} != "") && !($AUTH_EXPR)\`
handle @invalid_key {
	respond "Invalid API Key" 401
}
EOF
        echo "API authentication snippet created with $TOTAL_KEYS key(s) (OPTIONAL mode - requests allowed without keys)"
    else
        # Required mode: block unauthorized requests
        cat > "$AUTH_SNIPPET" <<EOF
@unauthorized not expression \`$AUTH_EXPR\`
handle @unauthorized {
	respond "Unauthorized" 401
}
EOF
        echo "API authentication snippet created with $TOTAL_KEYS key(s) (REQUIRED mode)"
    fi
else
    # Create empty auth snippet
    echo "" > "$AUTH_SNIPPET"
    echo "API authentication disabled"
fi

# Execute Caddy (replaces this script process with PID 1)
exec /usr/bin/caddy run --config /etc/caddy/Caddyfile --adapter caddyfile
