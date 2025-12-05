#!/bin/sh
set -e

AUTH_SNIPPET="/config/auth.caddyfile"

# Only do API key logic if authentication is enabled
if [ "${API_AUTH_ENABLED}" = "true" ]; then
    API_KEY_FILE="/data/api_key"

    if [ ! -f "$API_KEY_FILE" ]; then
        echo "==================================================================="
        echo "Generating new API key for authentication..."
        API_KEY=$(head -c 32 /dev/urandom | hexdump -ve '1/1 "%.2x"')
        echo "$API_KEY" > "$API_KEY_FILE"
        chmod 600 "$API_KEY_FILE"
        echo "==================================================================="
        echo "API Key: $API_KEY"
        echo "==================================================================="
        echo "IMPORTANT: Save this key securely"
        echo "The client can authenticate using either:"
        echo "  1. Header (recommended): X-API-Key: <key>"
        echo "  2. Query param: https://yourdomain.com?api_key=<key>"
        echo "To retrieve this key later: docker compose exec caddy cat /data/api_key"
        echo "==================================================================="
    else
        API_KEY=$(cat "$API_KEY_FILE")
        echo "==================================================================="
        echo "API authentication enabled"
        echo "Current API Key: $API_KEY"
        echo "==================================================================="
    fi

    export API_KEY

    # Create auth snippet
    cat > "$AUTH_SNIPPET" <<'EOF'
@unauthorized not expression `{header.X-API-Key} == {env.API_KEY} || {query.api_key} == {env.API_KEY}`
handle @unauthorized {
	respond "Unauthorized" 401
}
EOF

    echo "API authentication snippet created"
else
    # Create empty auth snippet
    echo "" > "$AUTH_SNIPPET"
    echo "API authentication disabled"
fi

# Execute Caddy (replaces this script process with PID 1)
exec /usr/bin/caddy run --config /etc/caddy/Caddyfile --adapter caddyfile
