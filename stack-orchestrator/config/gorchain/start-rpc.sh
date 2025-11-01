#!/bin/bash
set -e

# Configuration
AGAVE_CONFIG_DIR="/agave/config"
AGAVE_LEDGER_DIR="/agave/ledger"
AGAVE_ACCOUNTS_DIR="/agave/accounts"
RPC_INDENTITY="$AGAVE_CONFIG_DIR/validator-identity.json"

# Check required environment variables
: ${VALIDATOR_ENTRYPOINT:?}
: ${KNOWN_VALIDATOR:?}

# Environment variables with defaults
RPC_PORT="${RPC_PORT:-8899}"
GOSSIP_PORT="${GOSSIP_PORT:-8001}"
RUST_LOG="${RUST_LOG:-info}"

echo "Starting Agave RPC node (non-voting)..."
echo "Connecting to external validator at: ${VALIDATOR_ENTRYPOINT}"

# Create directories if they don't exist
mkdir -p "$AGAVE_CONFIG_DIR" "$AGAVE_LEDGER_DIR" "$AGAVE_ACCOUNTS_DIR"

# Fix ownership of mounted volumes
sudo chown -R $(id -u):$(id -g) "$AGAVE_CONFIG_DIR" "$AGAVE_LEDGER_DIR" "$AGAVE_ACCOUNTS_DIR" 2>/dev/null || true

# Generate RPC node identity if it doesn't exist
if [ ! -f "$RPC_INDENTITY" ]; then
    echo "Generating RPC node identity keypair..."
    solana-keygen new --no-passphrase --silent --force --outfile "$RPC_INDENTITY"
fi

echo "Configuring RPC node arguments..."
RPC_ARGS=(
    --identity "$RPC_INDENTITY"
    --known-validator "$KNOWN_VALIDATOR"
    --no-voting                                    # RPC node: no voting
    --entrypoint "$VALIDATOR_ENTRYPOINT"         # Connect to consensus validator
    --ledger "$AGAVE_LEDGER_DIR"
    --accounts "$AGAVE_ACCOUNTS_DIR"
    --log -
    --full-rpc-api                                 # Full public RPC
    --rpc-port "$RPC_PORT"
    --rpc-bind-address 0.0.0.0                     # Bind to all interfaces
    --dynamic-port-range 9000-9025
    --gossip-port "$GOSSIP_PORT"
    --only-known-rpc                               # Only bootstrap from known validators
    --enable-rpc-transaction-history
    --rpc-pubsub-enable-block-subscription
    --enable-extended-tx-metadata-storage
    --no-wait-for-vote-to-start-leader             # Start RPC immediately
    --no-os-network-limits-test
    --wal-recovery-mode skip_any_corrupted_record
    --limit-ledger-size                            # Limit disk usage
)

# Get RPC's public IP for gossip advertising
if [[ -n "$PUBLIC_RPC_ADDRESS" ]]; then
  RPC_ARGS+=(
    --public-rpc-address "$PUBLIC_RPC_ADDRESS"
  )
  echo "Public RPC address: $PUBLIC_RPC_ADDRESS"
else
  RPC_ARGS+=(
    --private-rpc
    --allow-private-addr
  )
  echo "No public RPC address set, assuming private RPC node"
fi

echo "RPC node args: ${RPC_ARGS[@]}"
exec agave-validator "${RPC_ARGS[@]}"
