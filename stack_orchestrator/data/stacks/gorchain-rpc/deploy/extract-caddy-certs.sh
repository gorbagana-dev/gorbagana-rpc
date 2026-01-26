#!/bin/bash
# Extract Let's Encrypt certificates from etcd backup using auger
# Usage: ./extract-caddy-certs.sh <backup-dir> [output-dir]
# Example: ./extract-caddy-certs.sh ./data/cluster-backups/laconic-abc123def456

set -e

BACKUP_DIR="${1:-.}"
OUTPUT_DIR="${2:-.}"

ETCD_DB="$BACKUP_DIR/etcd/member/snap/db"

# Check for required files
if [[ ! -f "$ETCD_DB" ]]; then
    # Check if it exists but we can't read it (permissions)
    if [[ -d "$BACKUP_DIR/etcd/member" ]] && ! ls "$BACKUP_DIR/etcd/member" &>/dev/null; then
        echo "Error: Cannot read etcd data (permission denied)"
        echo "The etcd data is owned by root. Run with sudo:"
        echo "  sudo $0 $*"
        exit 1
    fi
    echo "Error: etcd database not found at $ETCD_DB"
    echo "Usage: $0 <backup-dir> [output-dir]"
    exit 1
fi

echo "Extracting certificates from: $ETCD_DB"
echo "Output directory: $OUTPUT_DIR"
echo ""

# Install auger if not present
AUGER_BIN="/tmp/auger-$$"
CLEANUP_AUGER=false

if command -v auger &> /dev/null; then
    AUGER_BIN="auger"
else
    echo "Installing auger..."

    # Detect OS and arch
    OS=$(uname -s | tr '[:upper:]' '[:lower:]')
    ARCH=$(uname -m)
    case $ARCH in
        x86_64) ARCH="amd64" ;;
        aarch64|arm64) ARCH="arm64" ;;
    esac

    # Download and extract from tarball
    AUGER_VERSION="1.0.3"
    AUGER_URL="https://github.com/etcd-io/auger/releases/download/v${AUGER_VERSION}/auger_${AUGER_VERSION}_${OS}_${ARCH}.tar.gz"
    if ! curl -sL "$AUGER_URL" 2>/dev/null | tar xz -C /tmp auger; then
        echo "Error: Failed to download auger from $AUGER_URL"
        echo "Install manually: go install github.com/etcd-io/auger@latest"
        exit 1
    fi
    AUGER_BIN="/tmp/auger"
    CLEANUP_AUGER=true
    echo "Installed auger to $AUGER_BIN"
fi

# Cleanup function
cleanup() {
    if [[ "$CLEANUP_AUGER" == "true" ]] && [[ -f "$AUGER_BIN" ]]; then
        rm -f "$AUGER_BIN"
        echo "Cleaned up auger binary"
    fi
}
trap cleanup EXIT

# List certificate secrets
echo "Searching for Caddy certificate secrets..."
CERT_KEYS=$("$AUGER_BIN" extract -f "$ETCD_DB" --template='{{.Key}}' 2>/dev/null | grep -E "/registry/secrets/caddy-system/caddy\.ingress--certificates" || true)

if [[ -z "$CERT_KEYS" ]]; then
    echo "No certificate secrets found in etcd backup"
    exit 0
fi

echo "Found certificates:"
echo "$CERT_KEYS" | while read key; do
    echo "  - $(basename "$key")"
done
echo ""

# Extract each certificate
echo "Extracting certificates..."
mkdir -p "$OUTPUT_DIR"

echo "$CERT_KEYS" | while read key; do
    [[ -z "$key" ]] && continue

    secret_name=$(basename "$key")

    # Extract domain from secret name
    # Format: caddy.ingress--certificates...domain.domain.crt
    if [[ "$secret_name" == *.crt ]]; then
        domain=$(echo "$secret_name" | sed -E 's/.*\.([^.]+\.[^.]+)\.crt$/\1/')
        output_file="$OUTPUT_DIR/${domain}.crt"
    elif [[ "$secret_name" == *.key ]]; then
        domain=$(echo "$secret_name" | sed -E 's/.*\.([^.]+\.[^.]+)\.key$/\1/')
        output_file="$OUTPUT_DIR/${domain}.key"
    else
        continue
    fi

    # Extract secret as JSON, parse the 'value' field, base64 decode
    secret_json=$("$AUGER_BIN" extract -f "$ETCD_DB" -k "$key" -o json 2>/dev/null)

    # The secret has data.value which is base64 encoded
    cert_data=$(echo "$secret_json" | grep -o '"value":"[^"]*"' | head -1 | sed 's/"value":"//;s/"$//' | base64 -d 2>/dev/null || true)

    if [[ -n "$cert_data" ]]; then
        echo "$cert_data" > "$output_file"
        echo "  Wrote: $output_file"
    else
        echo "  Warning: Could not extract data from $secret_name"
    fi
done

echo ""
echo "Done!"
echo ""
echo "Extracted files:"
ls -la "$OUTPUT_DIR"/*.crt "$OUTPUT_DIR"/*.key 2>/dev/null || echo "  (none found)"
