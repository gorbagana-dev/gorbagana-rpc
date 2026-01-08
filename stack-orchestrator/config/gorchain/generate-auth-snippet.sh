#!/bin/sh
# Shared function to generate Caddy auth snippet
# Used by both caddy-entrypoint.sh and manage-keys.sh

generate_auth_snippet() {
    API_KEYS_FILE="${1:-/data/api_keys}"
    AUTH_SNIPPET="${2:-/config/auth.caddyfile}"

    if [ ! -f "$API_KEYS_FILE" ]; then
        echo "" > "$AUTH_SNIPPET"
        return 0
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

    if [ "$TOTAL_KEYS" -eq 0 ]; then
        echo "" > "$AUTH_SNIPPET"
        return 0
    fi

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
}
