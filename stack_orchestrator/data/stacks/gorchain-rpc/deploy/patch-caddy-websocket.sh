#!/bin/bash
# Patch Caddy ingress for WebSocket support (HTTP/1.1 + WS route)
# Usage: patch-caddy-websocket.sh <service-fqdn> <hostname> <ws-port>
set -e

SERVICE_FQDN="${1:?Usage: $0 <service-fqdn> <hostname> <ws-port>}"
HOST="${2:?Usage: $0 <service-fqdn> <hostname> <ws-port>}"
WS_PORT="${3:?Usage: $0 <service-fqdn> <hostname> <ws-port>}"

echo "Patching Caddy for WebSocket support..."
echo "  Service: $SERVICE_FQDN:$WS_PORT"
echo "  Host: $HOST"

# Port-forward to Caddy admin API
kubectl -n caddy-system port-forward deployment/caddy-ingress-controller 2019:2019 &
PF_PID=$!
trap "kill $PF_PID 2>/dev/null" EXIT
sleep 3

# 1. Set protocols to h1 (required for WebSocket upgrade)
echo "Setting protocols to h1..."
curl -s -X PUT -H "Content-Type: application/json" \
  -d '["h1"]' \
  http://localhost:2019/config/apps/http/servers/ingress_server/protocols

# 2. Add WebSocket route at index 0 (takes priority over HTTP route)
echo "Adding WebSocket route..."
curl -s -X PUT -H "Content-Type: application/json" \
  -d "{
    \"handle\": [{
      \"handler\": \"reverse_proxy\",
      \"transport\": {\"protocol\": \"http\"},
      \"upstreams\": [{\"dial\": \"${SERVICE_FQDN}:${WS_PORT}\"}]
    }],
    \"match\": [{
      \"host\": [\"${HOST}\"],
      \"header\": {\"Upgrade\": [\"websocket\"]},
      \"protocol\": \"https\"
    }]
  }" \
  http://localhost:2019/config/apps/http/servers/ingress_server/routes/0

echo "Done!"
