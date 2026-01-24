#!/bin/sh
set -e

# Source the shared auth snippet generator
. /scripts/generate-auth-snippet.sh

API_KEYS_FILE="/data/api_keys"
AUTH_SNIPPET="/config/auth.caddyfile"
CADDY_ADMIN="http://127.0.0.1:2019"

print_usage() {
    cat <<EOF
API Key Management Script for Caddy

Usage:
  $0 <command> [arguments]

Commands:
  add [key]       Add a new API key (generates random key if not provided)
  list            List all API keys
  remove <key>    Remove an API key
  help            Show this help message

Examples:
  # Add a new random API key
  $0 add

  # Add a specific API key
  $0 add my-custom-key-12345

  # List all keys
  $0 list

  # Remove a key
  $0 remove my-custom-key-12345

Note: After adding or removing keys, Caddy config will be automatically reloaded.
      This causes a brief (~1-2 second) reload but maintains active connections.

EOF
}

generate_key() {
    head -c 32 /dev/urandom | hexdump -ve '1/1 "%.2x"'
}

reload_caddy_config() {
    echo "Reloading Caddy configuration..."

    # Regenerate auth snippet using shared function
    generate_auth_snippet "$API_KEYS_FILE" "$AUTH_SNIPPET"

    # Trigger Caddy reload via admin API
    echo "Attempting to reload via ${CADDY_ADMIN}/load..."

    RELOAD_OUTPUT=$(wget -O- --post-file=/etc/caddy/Caddyfile \
        --header="Content-Type: text/caddyfile" \
        "${CADDY_ADMIN}/load" 2>&1)
    RELOAD_STATUS=$?

    if [ $RELOAD_STATUS -eq 0 ]; then
        echo "✓ Caddy configuration reloaded successfully"
        echo ""
        echo "Note: If changes don't take effect, you may need to restart Caddy"
        return 0
    else
        echo "✗ Failed to reload Caddy configuration (exit code: $RELOAD_STATUS)"
        echo ""
        echo "Error details:"
        echo "$RELOAD_OUTPUT"
        echo ""
        echo "You may need to restart the container for changes to take effect"
        return 1
    fi
}

cmd_add() {
    # Ensure keys file exists
    if [ ! -f "$API_KEYS_FILE" ]; then
        touch "$API_KEYS_FILE"
        chmod 600 "$API_KEYS_FILE"
    fi

    # Generate or use provided key
    if [ -z "$1" ]; then
        NEW_KEY=$(generate_key)
        echo "Generated new API key"
    else
        NEW_KEY="$1"
        echo "Adding custom API key"
    fi

    # Check if key already exists
    if grep -Fxq "$NEW_KEY" "$API_KEYS_FILE" 2>/dev/null; then
        echo "⚠ Key already exists"
        return 1
    fi

    # Add key to file
    echo "$NEW_KEY" >> "$API_KEYS_FILE"

    echo "==================================================================="
    echo "✓ API Key added successfully"
    echo "==================================================================="
    echo "Key: $NEW_KEY"
    echo ""
    echo "The client can authenticate using either:"
    echo "  1. Header (recommended): X-API-Key: $NEW_KEY"
    echo "  2. Query param: https://yourdomain.com?api_key=$NEW_KEY"
    echo "==================================================================="

    # Reload Caddy config
    reload_caddy_config
}

cmd_list() {
    if [ ! -f "$API_KEYS_FILE" ]; then
        echo "No API keys found"
        return 1
    fi

    echo "==================================================================="
    echo "Current API Keys:"
    echo "==================================================================="

    KEY_INDEX=1
    while IFS= read -r key || [ -n "$key" ]; do
        # Skip empty lines and comments
        if [ -n "$key" ] && [ "${key#\#}" = "$key" ]; then
            echo "[$KEY_INDEX] $key"
            KEY_INDEX=$((KEY_INDEX + 1))
        fi
    done < "$API_KEYS_FILE"

    TOTAL=$((KEY_INDEX - 1))
    echo "==================================================================="
    echo "Total: $TOTAL key(s)"
    echo "==================================================================="
}

cmd_remove() {
    if [ -z "$1" ]; then
        echo "Error: No key specified"
        echo "Usage: $0 remove <key>"
        return 1
    fi

    KEY_TO_REMOVE="$1"

    if [ ! -f "$API_KEYS_FILE" ]; then
        echo "Error: No API keys file found"
        return 1
    fi

    # Check if key exists
    if ! grep -Fxq "$KEY_TO_REMOVE" "$API_KEYS_FILE"; then
        echo "Error: Key not found"
        return 1
    fi

    # Remove the key (using a temp file for safety)
    grep -Fxv "$KEY_TO_REMOVE" "$API_KEYS_FILE" > "${API_KEYS_FILE}.tmp" || true
    mv "${API_KEYS_FILE}.tmp" "$API_KEYS_FILE"

    echo "✓ API key removed successfully"

    # Reload Caddy config
    reload_caddy_config
}

# Main command dispatcher
case "${1:-help}" in
    add)
        cmd_add "$2"
        ;;
    list)
        cmd_list
        ;;
    remove)
        cmd_remove "$2"
        ;;
    help|--help|-h)
        print_usage
        ;;
    *)
        echo "Error: Unknown command '$1'"
        echo ""
        print_usage
        exit 1
        ;;
esac
