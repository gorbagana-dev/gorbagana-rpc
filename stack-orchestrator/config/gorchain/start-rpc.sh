#!/bin/bash
set -e

# Configuration
AGAVE_CONFIG_DIR="/agave/config"
AGAVE_LEDGER_DIR="/agave/ledger"
AGAVE_ACCOUNTS_DIR="/agave/accounts"
RPC_IDENTITY="$AGAVE_CONFIG_DIR/rpc-identity.json"

# Environment variables with defaults
VOTING_NODE_ENTRYPOINT="${VOTING_NODE_ENTRYPOINT:-agave-validator:8001}"
VOTING_NODE_IDENTITY="${VOTING_NODE_IDENTITY:-/agave/voter-config/validator-identity.json}"
RPC_PORT="${RPC_PORT:-8899}"
GOSSIP_PORT="${GOSSIP_PORT:-8001}"
RUST_LOG="${RUST_LOG:-info}"

echo "Starting Agave RPC node (non-voting)..."
echo "Connecting to consensus validator at: ${VOTING_NODE_ENTRYPOINT}"

# Create directories if they don't exist
mkdir -p "$AGAVE_CONFIG_DIR" "$AGAVE_LEDGER_DIR" "$AGAVE_ACCOUNTS_DIR"

# Fix ownership of mounted volumes
sudo chown -R $(id -u):$(id -g) "$AGAVE_CONFIG_DIR" "$AGAVE_LEDGER_DIR" "$AGAVE_ACCOUNTS_DIR" 2>/dev/null || true

# Generate RPC node identity if it doesn't exist
if [ ! -f "$RPC_IDENTITY" ]; then
    echo "Generating RPC node identity keypair..."
    solana-keygen new --no-passphrase --silent --force --outfile "$RPC_IDENTITY"
fi

# Use known validator if passed, fall back to identity file
if [ -z "$KNOWN_VALIDATOR" ]; then
  if [ -f "$VOTING_NODE_IDENTITY" ]; then
    KNOWN_VALIDATOR="$(solana-keygen pubkey "$VOTING_NODE_IDENTITY" 2>/dev/null)"
  else
    echo "Error: KNOWN_VALIDATOR not set and voting node identity file not found at $VOTING_NODE_IDENTITY"
    exit 1
  fi
fi

# RPC node arguments
echo "Configuring RPC node arguments..."
RPC_ARGS=(
    --identity "$RPC_IDENTITY"
    --known-validator "$KNOWN_VALIDATOR"
    --no-voting                                    # RPC node: no voting
    --entrypoint "$VOTING_NODE_ENTRYPOINT"         # Connect to consensus validator
    --ledger "$AGAVE_LEDGER_DIR"
    --accounts "$AGAVE_ACCOUNTS_DIR"
    --log -
    --full-rpc-api                                 # Full public RPC
    --rpc-port "$RPC_PORT"
    --rpc-bind-address 0.0.0.0                     # Public RPC access
    --dynamic-port-range 9000-9025
    --gossip-port "$GOSSIP_PORT"
    --private-rpc
    --only-known-rpc                               # Only bootstrap from known validators
    --allow-private-addr                           # Allow private network addresses
    --enable-rpc-transaction-history               # Full transaction history
    --rpc-pubsub-enable-block-subscription         # WebSocket subscriptions
    --enable-extended-tx-metadata-storage          # Extended metadata
    --no-wait-for-vote-to-start-leader             # Start RPC immediately
    --no-os-network-limits-test
    --wal-recovery-mode skip_any_corrupted_record
    --limit-ledger-size                            # Limit disk usage
)

echo "RPC node args: ${RPC_ARGS[@]}"
exec agave-validator "${RPC_ARGS[@]}"
