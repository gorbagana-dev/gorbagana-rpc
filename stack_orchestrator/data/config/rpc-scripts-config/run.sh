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

# Defaults for these are set in compose file
: ${RPC_PORT:?}
: ${GOSSIP_PORT:?}
: ${DYNAMIC_PORT_RANGE:?}

# Environment variables with defaults
RUST_LOG="${RUST_LOG:-info}"

# Snapshot cadence — see gorbagana/gor-001 (validator) and gor-003
# (this rpc side) in laconic-tech-ops infra/gorbagana/.pebbles/.
#
# Do NOT set --no-incremental-snapshots together with
# --full-snapshot-interval-slots: agave 3.x silently ignores the
# latter when incrementals are disabled, producing zero runtime
# snapshots and unbounded cold-boot replay tails.
#
# SNAPSHOT_INTERVAL_SLOTS is the INCREMENTAL cadence (was previously
# fed to --full-snapshot-interval-slots, which was the bug).
# FULL_SNAPSHOT_INTERVAL_SLOTS is new — full-snapshot cadence.
# Old MAXIMUM_SNAPSHOTS_TO_RETAIN is honored as a fallback so
# deployments that haven't been re-specced still work; new name is
# MAXIMUM_FULL_SNAPSHOTS_TO_RETAIN.
SNAPSHOT_INTERVAL_SLOTS="${SNAPSHOT_INTERVAL_SLOTS:-500}"
FULL_SNAPSHOT_INTERVAL_SLOTS="${FULL_SNAPSHOT_INTERVAL_SLOTS:-25000}"
MAXIMUM_FULL_SNAPSHOTS_TO_RETAIN="${MAXIMUM_FULL_SNAPSHOTS_TO_RETAIN:-${MAXIMUM_SNAPSHOTS_TO_RETAIN:-2}}"
MAXIMUM_INCREMENTAL_SNAPSHOTS_TO_RETAIN="${MAXIMUM_INCREMENTAL_SNAPSHOTS_TO_RETAIN:-4}"

# Build SOLANA_METRICS_CONFIG from sub-vars; an explicit value wins.
if [ -z "${SOLANA_METRICS_CONFIG:-}" ] \
   && [ -n "${INFLUXDB_HOST:-}" ] \
   && [ -n "${INFLUXDB_WRITE_USER:-}" ] \
   && [ -n "${INFLUXDB_WRITE_PASSWORD:-}" ]; then
    export SOLANA_METRICS_CONFIG="host=${INFLUXDB_HOST},db=${INFLUXDB_DB:-agave_metrics},u=${INFLUXDB_WRITE_USER},p=${INFLUXDB_WRITE_PASSWORD}"
fi

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

echo "Node identity (pubkey): $(solana-keygen pubkey "$RPC_INDENTITY")"

echo "Configuring RPC node arguments..."
RPC_ARGS=(
    --identity "$RPC_INDENTITY"
    --known-validator "$KNOWN_VALIDATOR"
    --only-known-rpc                               # Only fetch snapshots from known validators
    --no-voting                                    # RPC node: no voting
    --entrypoint "$VALIDATOR_ENTRYPOINT"         # Connect to consensus validator
    --ledger "$AGAVE_LEDGER_DIR"
    --accounts "$AGAVE_ACCOUNTS_DIR"
    --log -
    --full-rpc-api                                 # Full public RPC
    --rpc-port "$RPC_PORT"
    --rpc-bind-address 0.0.0.0                     # Bind to all interfaces
    --gossip-port "$GOSSIP_PORT"
    --dynamic-port-range "$DYNAMIC_PORT_RANGE"
    --enable-rpc-transaction-history
    --rpc-pubsub-enable-block-subscription
    --enable-extended-tx-metadata-storage
    --no-wait-for-vote-to-start-leader             # Start RPC immediately
    --no-os-network-limits-test
    --no-port-check                                  # Skip UDP port check (containerized env)
    --wal-recovery-mode skip_any_corrupted_record
    --limit-ledger-size                            # Limit disk usage
    # Snapshot cadence — see env-default block above for why these
    # flags and why we no longer set --no-incremental-snapshots.
    --snapshot-interval-slots "$SNAPSHOT_INTERVAL_SLOTS"
    --full-snapshot-interval-slots "$FULL_SNAPSHOT_INTERVAL_SLOTS"
    --maximum-full-snapshots-to-retain "$MAXIMUM_FULL_SNAPSHOTS_TO_RETAIN"
    --maximum-incremental-snapshots-to-retain "$MAXIMUM_INCREMENTAL_SNAPSHOTS_TO_RETAIN"
    # Bound accounts-db cache the same way as the validator.
    # --accounts-index-limit is NOT in agave 3.0.9; do not add it.
    --accounts-db-cache-limit-mb 1024
    # Restrict repair requests to the known validator
    --repair-validator "$KNOWN_VALIDATOR"
     # Max genesis archive unpacked size 50MB
    --max-genesis-archive-unpacked-size 50000000
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

# Configure faucet address for requestAirdrop RPC
if [[ -n "$FAUCET_ADDRESS" ]]; then
  RPC_ARGS+=(
    --rpc-faucet-address "$FAUCET_ADDRESS"
  )
  echo "Faucet address configured: $FAUCET_ADDRESS"
fi

echo "RPC node args: ${RPC_ARGS[@]}"
exec agave-validator "${RPC_ARGS[@]}"
