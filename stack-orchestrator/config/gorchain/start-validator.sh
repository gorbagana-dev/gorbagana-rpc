#!/bin/bash
set -e

# Configuration
AGAVE_CONFIG_DIR="/agave/config"
AGAVE_LEDGER_DIR="/agave/ledger"
AGAVE_ACCOUNTS_DIR="/agave/accounts"
VALIDATOR_IDENTITY="$AGAVE_CONFIG_DIR/validator-identity.json"
VALIDATOR_VOTE_ACCOUNT="$AGAVE_CONFIG_DIR/validator-vote-account.json"
VALIDATOR_STAKE_ACCOUNT="$AGAVE_CONFIG_DIR/validator-stake-account.json"

# Environment variables with defaults
CLUSTER_TYPE="${CLUSTER_TYPE:-testnet}"
RUST_LOG="${RUST_LOG:-info}"
FAUCET_LAMPORTS="${FAUCET_LAMPORTS:-500000000000000000}"
RPC_PORT="${RPC_PORT:-8899}"
FAUCET_PORT="${FAUCET_PORT:-9900}"
GOSSIP_PORT="${GOSSIP_PORT:-8001}"
# Public addresses default to Docker internal hosts
PUBLIC_GOSSIP_HOST="${PUBLIC_GOSSIP_HOST:-agave-validator}"
PUBLIC_RPC_ADDRESS="${PUBLIC_RPC_ADDRESS:-agave-validator:$RPC_PORT}"
INIT_COMPLETE_FILE="${INIT_COMPLETE_FILE:-}" # Optional file to create when validator is ready

echo "Starting Agave validator..."
echo "Cluster type: $CLUSTER_TYPE"
echo "Config dir: $AGAVE_CONFIG_DIR"
echo "Ledger dir: $AGAVE_LEDGER_DIR"
echo "Accounts dir: $AGAVE_ACCOUNTS_DIR"

# Validate required binaries are available
echo "Validating required binaries..."
ok=true
for program in solana-{faucet,genesis,keygen}; do
  if ! $program -V >/dev/null 2>&1; then
    echo "ERROR: Required program '$program' not found or not working"
    ok=false
  fi
done
if ! agave-validator -V >/dev/null 2>&1; then
  echo "ERROR: Required program 'agave-validator' not found or not working"
  ok=false
fi

if [[ "$ok" != "true" ]]; then
  echo "FATAL: Missing required binaries. Cannot start validator."
  echo "Make sure all Solana/Agave programs are installed and in PATH"
  exit 1
fi
echo "✅ All required binaries validated"

# Create directories if they don't exist
mkdir -p "$AGAVE_CONFIG_DIR" "$AGAVE_LEDGER_DIR" "$AGAVE_ACCOUNTS_DIR"

# Fix ownership of mounted volumes (Docker volume mounts override internal ownership)
echo "🔧 Fixing ownership of mounted volumes..."
echo "Current user: $(whoami) (UID: $(id -u), GID: $(id -g))"
echo "Directory ownership before fix:"
ls -la "$AGAVE_CONFIG_DIR" "$AGAVE_LEDGER_DIR" "$AGAVE_ACCOUNTS_DIR" 2>/dev/null || echo "Directories don't exist yet"

# The real issue: volume mounts override the container's internal directory ownership
# We need to ensure the agave user can write to these mounted directories
if [ ! -w "$AGAVE_CONFIG_DIR" ]; then
    echo "⚠️  Config directory is not writable by current user, attempting to fix..."
    sudo chown -R $(id -u):$(id -g) "$AGAVE_CONFIG_DIR" 2>/dev/null || true
fi
if [ ! -w "$AGAVE_LEDGER_DIR" ]; then
    echo "⚠️  Ledger directory is not writable by current user, attempting to fix..."
    sudo chown -R $(id -u):$(id -g) "$AGAVE_LEDGER_DIR" 2>/dev/null || true
fi
if [ ! -w "$AGAVE_ACCOUNTS_DIR" ]; then
    echo "⚠️  Accounts directory is not writable by current user, attempting to fix..."
    sudo chown -R $(id -u):$(id -g) "$AGAVE_ACCOUNTS_DIR" 2>/dev/null || true
fi

echo "Directory ownership after fix:"
ls -la "$AGAVE_CONFIG_DIR" "$AGAVE_LEDGER_DIR" "$AGAVE_ACCOUNTS_DIR" 2>/dev/null || echo "Still checking..."

# Ensure ledger directory has proper structure for RocksDB
mkdir -p "$AGAVE_LEDGER_DIR/rocksdb"
chmod 755 "$AGAVE_LEDGER_DIR/rocksdb"

# Check if keypair files exist and are readable - recreate if not
echo "🔧 Ensuring keypair files are accessible..."
NEED_RECREATE_FAUCET=false
NEED_RECREATE_IDENTITY=false
NEED_RECREATE_VOTE=false
NEED_RECREATE_STAKE=false
NEED_RECREATE_KNOWN=false
NEED_RECREATE_UPGRADE_AUTHORITY=false

# Set default known validator keypair path for checking
KNOWN_VALIDATOR_KEYPAIR="$AGAVE_CONFIG_DIR/known-validator.json"
UPGRADE_AUTHORITY_KEYPAIR="$AGAVE_CONFIG_DIR/upgrade-authority.json"

if [[ -f "$AGAVE_CONFIG_DIR/faucet-keypair.json" ]] && [[ ! -r "$AGAVE_CONFIG_DIR/faucet-keypair.json" ]]; then
    echo "⚠️  Faucet keypair exists but is not readable - will recreate..."
    rm -f "$AGAVE_CONFIG_DIR/faucet-keypair.json" 2>/dev/null || true
    NEED_RECREATE_FAUCET=true
fi

if [[ -f "$VALIDATOR_IDENTITY" ]] && [[ ! -r "$VALIDATOR_IDENTITY" ]]; then
    echo "⚠️  Validator identity exists but is not readable - will recreate..."
    rm -f "$VALIDATOR_IDENTITY" 2>/dev/null || true
    NEED_RECREATE_IDENTITY=true
fi

if [[ -f "$VALIDATOR_VOTE_ACCOUNT" ]] && [[ ! -r "$VALIDATOR_VOTE_ACCOUNT" ]]; then
    echo "⚠️  Vote account exists but is not readable - will recreate..."
    rm -f "$VALIDATOR_VOTE_ACCOUNT" 2>/dev/null || true
    NEED_RECREATE_VOTE=true
fi

if [[ -f "$VALIDATOR_STAKE_ACCOUNT" ]] && [[ ! -r "$VALIDATOR_STAKE_ACCOUNT" ]]; then
    echo "⚠️  Stake account exists but is not readable - will recreate..."
    rm -f "$VALIDATOR_STAKE_ACCOUNT" 2>/dev/null || true
    NEED_RECREATE_STAKE=true
fi

if [[ -f "$KNOWN_VALIDATOR_KEYPAIR" ]] && [[ ! -r "$KNOWN_VALIDATOR_KEYPAIR" ]]; then
    echo "⚠️  Known validator keypair exists but is not readable - will recreate..."
    rm -f "$KNOWN_VALIDATOR_KEYPAIR" 2>/dev/null || true
    NEED_RECREATE_KNOWN=true
fi

if [[ -f "$UPGRADE_AUTHORITY_KEYPAIR" ]] && [[ ! -r "$UPGRADE_AUTHORITY_KEYPAIR" ]]; then
    echo "⚠️  Known validator keypair exists but is not readable - will recreate..."
    rm -f "$UPGRADE_AUTHORITY_KEYPAIR" 2>/dev/null || true
    NEED_RECREATE_UPGRADE_AUTHORITY=true
fi

# Create keypairs in temporary directory to avoid Docker volume permission issues
if [[ "$NEED_RECREATE_FAUCET" == "true" ]] || [[ "$NEED_RECREATE_IDENTITY" == "true" ]] || [[ "$NEED_RECREATE_VOTE" == "true" ]] || [[ "$NEED_RECREATE_STAKE" == "true" ]] || [[ "$NEED_RECREATE_KNOWN" == "true" ]]; then
    echo "🔧 Creating keypairs in temporary directory to avoid volume permission issues..."
    TEMP_CONFIG_DIR="/tmp/agave-keypairs"
    mkdir -p "$TEMP_CONFIG_DIR"
    chmod 755 "$TEMP_CONFIG_DIR"
fi

# Immediately recreate any removed keypairs in temporary directory and update paths
if [[ "$NEED_RECREATE_FAUCET" == "true" ]]; then
    echo "🔑 Recreating faucet keypair..."
    solana-keygen new --no-passphrase --silent --force --outfile "$TEMP_CONFIG_DIR/faucet-keypair.json"
    # Update the faucet keypair path to use temporary file
    FAUCET_KEYPAIR="$TEMP_CONFIG_DIR/faucet-keypair.json"
    echo "✅ Using temporary faucet keypair: $FAUCET_KEYPAIR"
fi

if [[ "$NEED_RECREATE_IDENTITY" == "true" ]]; then
    echo "🔑 Recreating validator identity keypair..."
    solana-keygen new --no-passphrase --silent --force --outfile "$TEMP_CONFIG_DIR/validator-identity.json"
    VALIDATOR_IDENTITY="$TEMP_CONFIG_DIR/validator-identity.json"
    echo "✅ Using temporary validator identity keypair: $VALIDATOR_IDENTITY"
fi

if [[ "$NEED_RECREATE_VOTE" == "true" ]]; then
    echo "🔑 Recreating vote account keypair..."
    solana-keygen new --no-passphrase --silent --force --outfile "$TEMP_CONFIG_DIR/vote-account.json"
    VALIDATOR_VOTE_ACCOUNT="$TEMP_CONFIG_DIR/vote-account.json"
    echo "✅ Using temporary vote account keypair: $VALIDATOR_VOTE_ACCOUNT"
fi

if [[ "$NEED_RECREATE_STAKE" == "true" ]]; then
    echo "🔑 Recreating stake account keypair..."
    solana-keygen new --no-passphrase --silent --force --outfile "$TEMP_CONFIG_DIR/stake-account.json"
    VALIDATOR_STAKE_ACCOUNT="$TEMP_CONFIG_DIR/stake-account.json"
    echo "✅ Using temporary stake account keypair: $VALIDATOR_STAKE_ACCOUNT"
fi

if [[ "$NEED_RECREATE_KNOWN" == "true" ]]; then
    echo "🔑 Recreating known validator keypair..."
    solana-keygen new --no-passphrase --silent --force --outfile "$TEMP_CONFIG_DIR/known-validator.json"
    KNOWN_VALIDATOR_KEYPAIR="$TEMP_CONFIG_DIR/known-validator.json"
    echo "✅ Using temporary known validator keypair: $KNOWN_VALIDATOR_KEYPAIR"
fi

if [[ "$NEED_RECREATE_UPGRADE_AUTHORITY" == "true" ]]; then
    echo "🔑 Recreating upgrade authority keypair..."
    solana-keygen new --no-passphrase --silent --force --outfile "$TEMP_CONFIG_DIR/upgrade-authority.json"
    UPGRADE_AUTHORITY_KEYPAIR="$TEMP_CONFIG_DIR/upgrade-authority.json"
    echo "✅ Using temporary upgrade authority keypair: $UPGRADE_AUTHORITY_KEYPAIR"
fi

echo "✅ All keypair files are now accessible"

# Generate validator identity keypair if it doesn't exist
if [[ ! -f "$VALIDATOR_IDENTITY" ]]; then
    echo "Generating validator identity keypair..."
    solana-keygen new --no-passphrase --silent --force --outfile "$VALIDATOR_IDENTITY"
fi

# Generate vote account keypair if it doesn't exist
if [[ ! -f "$VALIDATOR_VOTE_ACCOUNT" ]]; then
    echo "Generating validator vote account keypair..."
    solana-keygen new --no-passphrase --silent --force --outfile "$VALIDATOR_VOTE_ACCOUNT"
fi

# Generate stake account keypair if it doesn't exist
if [[ ! -f "$VALIDATOR_STAKE_ACCOUNT" ]]; then
    echo "Generating validator stake account keypair..."
    solana-keygen new --no-passphrase --silent --force --outfile "$VALIDATOR_STAKE_ACCOUNT"
fi

# Generate faucet keypair if faucet is enabled
# Only set default faucet keypair path if we didn't recreate it
if [[ "$NEED_RECREATE_FAUCET" != "true" ]]; then
    FAUCET_KEYPAIR="$AGAVE_CONFIG_DIR/faucet-keypair.json"
fi
if [[ "${ENABLE_FAUCET:-true}" == "true" ]]; then
    if [[ ! -f "$FAUCET_KEYPAIR" ]]; then
        echo "Generating faucet keypair..."
        solana-keygen new --no-passphrase --silent --force --outfile "$FAUCET_KEYPAIR"
    fi
fi

# Generate a dummy known validator keypair for single-node development
# This is required because agave-validator requires at least one known validator
# Only set default path if we didn't recreate it in temporary directory
if [[ "$NEED_RECREATE_KNOWN" != "true" ]]; then
    KNOWN_VALIDATOR_KEYPAIR="$AGAVE_CONFIG_DIR/known-validator.json"
fi

if [[ ! -f "$KNOWN_VALIDATOR_KEYPAIR" ]]; then
    echo "Generating known validator keypair for development..."
    solana-keygen new --no-passphrase --silent --force --outfile "$KNOWN_VALIDATOR_KEYPAIR"
fi

if [[ ! -f "$UPGRADE_AUTHORITY_KEYPAIR" ]]; then
    echo "Generating known validator keypair for development..."
    solana-keygen new --no-passphrase --silent --force --outfile "$UPGRADE_AUTHORITY_KEYPAIR"
fi



# JSON program data matching the commented examples above
JSON_PROGRAM_DATA='[
  {
    "program": "TokenzQdBNbLqP5VEhdkAS6EPFLC1PHnBqCXEpPxuEb",
    "path": "/agave/programs/spl-token-2022-9.0.0.so",
    "type": "upgradeable"
  },
  {
    "program": "Memo1UhkJRfHyvLMcVucJwxXeuD728EqVDDwQDxFMNo",
    "path": "/agave/programs/spl-memo-1.0.0.so",
    "type": "bpf"
  },
  {
    "program": "MemoSq4gqABAXKb96qnH8TysNcWxMyWCqXgDLGmfcHr",
    "path": "/agave/programs/spl-memo-3.0.0.so",
    "type": "bpfv2"
  },
  {
    "program": "ATokenGPvbdGVxr1b2hvZbsiqW5xWH25efTNsLJA8knL",
    "path": "/agave/programs/spl-associated-token-account-1.1.2.so",
    "type": "bpfv2"
  },
  {
    "program": "Feat1YXHhH6t1juaWF74WLcfv4XoNocjXA6sPWHNgAse",
    "path": "/agave/programs/spl-feature-proposal-1.0.0.so",
    "type": "bpfv2"
  },
  {
    "program": "TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA",
    "path": "/agave/programs/spl-token-3.5.0.so",
    "type": "bpfv2"
  },
  {
    "program": "metaqbxxUerdq28cj1RbAWkYQm3ybzjb6a8bt518x1s",
    "path": "/agave/programs/mpl_token_metadata.so",
    "type": "upgradeable"
  },
  {
    "program": "Feature111111111111111111111111111111111111",
    "path": "/agave/programs/core-bpf-feature-gate-0.0.1.so",
    "type": "upgradeable"
  },
  {
    "program": "AddressLookupTab1e1111111111111111111111111",
    "path": "/agave/programs/core-bpf-address-lookup-table-3.0.0.so",
    "type": "upgradeable"
  },
  {
    "program": "Config1111111111111111111111111111111111111",
    "path": "/agave/programs/core-bpf-config-3.0.0.so",
    "type": "upgradeable"
  },
  {
    "program": "namesLPneVptA9Z5rqUDD9tMTWEJwofgaYwp8cawRkX",
    "path": "/agave/programs/names-3.0.0.so",
    "type": "upgradeable"
  },
  {
    "program": "dbcij3LWUppWqq96dh6gJWwBifmcGfLSB5D4DuSMaqN",
    "path": "/agave/programs/precompiled/dynamic_bonding_curve-1.0.0.so",
    "type": "upgradeable"
  },
  {
    "program": "cpamdpZCGKUy5JxQXB4dcpGPiikHawvSWAd6mEn1sGG",
    "path": "/agave/programs/precompiled/cp_amm.so",
    "type": "upgradeable"
  }
]'


dump_bpf_program() {
    local program_id=$1
    local program_path=$2

    # Skip dumping if the path starts with /agave/programs/precompiled
    if [[ "$program_path" == /agave/programs/precompiled* ]]; then
        echo "Listing programs directory:"
        find /agave/programs
        echo "Skipping dump for precompiled program: $program_id (path: $program_path)"
        return 0
    fi

    echo "Dumping program: $program_id (path: $program_path)"
    solana -ut program dump $program_id $program_path
}

make_bpf_program_argument() {
    local program_id=$1
    local program_path=$2
    local program_type=$3

    if [[ "$program_type" == "upgradeable" ]]; then
        echo "--upgradeable-program $program_id BPFLoaderUpgradeab1e11111111111111111111111 $program_path $UPGRADE_AUTHORITY_KEYPAIR"
    elif [[ "$program_type" == "bpfv2" ]]; then
        echo "--bpf-program $program_id BPFLoader2111111111111111111111111111111111 $program_path"
    else
        echo "--bpf-program $program_id BPFLoader1111111111111111111111111111111111 $program_path"
    fi
}

# Create genesis if it doesn't exist
if [[ ! -f "$AGAVE_LEDGER_DIR/genesis.bin" && ! -f "$AGAVE_LEDGER_DIR/genesis.tar.bz2" ]]; then
    echo "Creating genesis block with standard programs..."

    echo "Using pre-downloaded SPL programs..."
    BPF_PROGRAM_ARGS=""

    # Parse JSON and extract program data
    while IFS= read -r line; do
        if [[ $line =~ \"program\":[[:space:]]*\"([^\"]+)\" ]]; then
            program_id="${BASH_REMATCH[1]}"
        elif [[ $line =~ \"path\":[[:space:]]*\"([^\"]+)\" ]]; then
            program_path="${BASH_REMATCH[1]}"
        elif [[ $line =~ \"type\":[[:space:]]*\"([^\"]+)\" ]]; then
            program_type="${BASH_REMATCH[1]}"
            # When we have all three pieces, generate the argument
            if [[ -n "$program_id" && -n "$program_path" && -n "$program_type" ]]; then
                # dump the program for use in the genesis command
                dump_bpf_program "$program_id" "$program_path"
                BPF_PROGRAM_ARGS+="$(make_bpf_program_argument "$program_id" "$program_path" "$program_type")"$'\n'
                # Reset for next program
                program_id=""
                program_path=""
                program_type=""
            fi
        fi
    done <<< "$JSON_PROGRAM_DATA"

    # Prepare genesis command arguments // TODO: In --upgradeable-program, replace the last argument `none` with the actual upgrade authority keypair before deploying to mainnet
    GENESIS_CMD=(
        solana-genesis
        --hashes-per-tick sleep
        --bootstrap-validator
            "$VALIDATOR_IDENTITY"
            "$VALIDATOR_VOTE_ACCOUNT"
            "$VALIDATOR_STAKE_ACCOUNT"
        --ledger "$AGAVE_LEDGER_DIR"
        --cluster-type "$CLUSTER_TYPE"
        $BPF_PROGRAM_ARGS
    )

    # Load the primordial accounts (i.e wSOL)
    if [[ -f /agave/primordial.yml ]]; then
        GENESIS_CMD+=(--primordial-accounts-file /agave/primordial.yml)
    fi

    # Add faucet configuration if enabled
    if [[ "${ENABLE_FAUCET:-true}" == "true" && -f "$FAUCET_KEYPAIR" ]]; then
        GENESIS_CMD+=(--faucet-lamports "$FAUCET_LAMPORTS")
        GENESIS_CMD+=(--faucet-pubkey "$FAUCET_KEYPAIR")
    fi

    # Add any additional genesis arguments (but filter out problematic ones)
    if [[ -n "$GENESIS_ARGS" ]]; then
        # Filter out any --faucet-pubkey arguments from GENESIS_ARGS to avoid conflicts
        FILTERED_GENESIS_ARGS=$(echo "$GENESIS_ARGS" | sed 's/--faucet-pubkey [^ ]*//g')
        if [[ -n "$FILTERED_GENESIS_ARGS" ]]; then
            GENESIS_CMD+=($FILTERED_GENESIS_ARGS)
        fi
    fi

    # Execute genesis creation
    echo "Creating genesis with command: ${GENESIS_CMD[@]}"
    "${GENESIS_CMD[@]}"

    echo "Genesis created successfully"
fi

# Start faucet in background if enabled
if [[ "${ENABLE_FAUCET:-true}" == "true" && -f "$FAUCET_KEYPAIR" ]]; then
    echo "Starting faucet..."
    echo "Faucet keypair: $FAUCET_KEYPAIR"
    echo "Faucet will be available at http://0.0.0.0:$FAUCET_PORT"

    # Start faucet with output redirection to see any errors
    echo "Executing: solana-faucet --keypair $FAUCET_KEYPAIR --per-request-cap 10 --per-time-cap 1000 --slice 10"
    solana-faucet --keypair "$FAUCET_KEYPAIR" --per-request-cap 10 --per-time-cap 1000 --slice 10 > /tmp/faucet.log 2>&1 &
    FAUCET_PID=$!
    echo "Faucet started with PID: $FAUCET_PID"

    # Give faucet a moment to start and check if it's still running
    sleep 3
    if kill -0 $FAUCET_PID 2>/dev/null; then
        echo "Faucet process is running"
        echo "Faucet log:"
        cat /tmp/faucet.log || echo "No faucet log available"
    else
        echo "ERROR: Faucet process died immediately"
        echo "Faucet log:"
        cat /tmp/faucet.log || echo "No faucet log available"
    fi
fi

# Get the known validator public key for the validator argument
KNOWN_VALIDATOR_PUBKEY=$(solana-keygen pubkey "$KNOWN_VALIDATOR_KEYPAIR")

# Prepare base validator arguments using clean array approach
echo "Configuring validator arguments..."
VALIDATOR_ARGS=(
    --identity "$VALIDATOR_IDENTITY"
    --vote-account "$VALIDATOR_VOTE_ACCOUNT"
    --ledger "$AGAVE_LEDGER_DIR"
    --accounts "$AGAVE_ACCOUNTS_DIR"
    --log -
    --full-rpc-api
    --rpc-port "$RPC_PORT"
    --rpc-bind-address 0.0.0.0  # Bind to all interfaces
    --gossip-port "$GOSSIP_PORT"
    --gossip-host "$PUBLIC_GOSSIP_HOST"  # Advertise public IP/hostname for external discovery
    --public-rpc-address "$PUBLIC_RPC_ADDRESS"
    --allow-private-addr
    --enable-rpc-transaction-history
    --rpc-pubsub-enable-block-subscription
    --enable-extended-tx-metadata-storage
    --no-wait-for-vote-to-start-leader
    --no-os-network-limits-test
    # Snapshot configuration for RPC node bootstrap
    # Set low intervals for dev/test to quickly create snapshots
    --full-snapshot-interval-slots "${SNAPSHOT_INTERVAL_SLOTS:-200}"
    --maximum-full-snapshots-to-retain "${MAXIMUM_SNAPSHOTS_TO_RETAIN:-2}"
    --no-incremental-snapshots
)

# Add init-complete-file if specified (useful for development/testing)
if [[ -n "$INIT_COMPLETE_FILE" ]]; then
    VALIDATOR_ARGS+=(--init-complete-file "$INIT_COMPLETE_FILE")
    echo "✅ Init complete file will be created at: $INIT_COMPLETE_FILE"
fi

# Configure based on cluster type
if [[ "$CLUSTER_TYPE" == "development" ]]; then
    echo "Configuring for single-node development mode"
    # Development mode optimizations for single-node setup
    # Keep current args - they're already optimized for development
elif [[ "$CLUSTER_TYPE" == "testnet" ]]; then
    echo "Configuring for single-node testnet mode"
    # Single-node testnet configuration - health check properly handles single-node setups
    # The health check will detect single-node mode and consider the validator healthy
    # if local slots are progressing, even without cluster consensus
else
    echo "Configuring for production mode"
    # Production mode - add security requirements where appropriate
    # Note: --require-tower causes waiting issues in single-node setup, so it's omitted
    VALIDATOR_ARGS+=(--known-validator "$KNOWN_VALIDATOR_PUBKEY")
fi

# Add faucet address if faucet is enabled and running
if [[ "${ENABLE_FAUCET:-true}" == "true" && -f "$FAUCET_KEYPAIR" ]]; then
    VALIDATOR_ARGS+=(--rpc-faucet-address "127.0.0.1:$FAUCET_PORT")
fi

# Add any additional validator arguments
if [[ -n "$VALIDATOR_ARGS_EXTRA" ]]; then
    VALIDATOR_ARGS+=($VALIDATOR_ARGS_EXTRA)
fi

# Setup signal handlers
cleanup() {
    echo "Shutting down..."
    if [[ -n "$FAUCET_PID" ]]; then
        kill "$FAUCET_PID" 2>/dev/null || true
    fi
    exit 0
}
trap cleanup INT TERM EXIT

# Switch to agave user for running the validator
echo "Starting validator as current user: $(whoami)..."
echo "Validator args: ${VALIDATOR_ARGS[@]}"
exec agave-validator "${VALIDATOR_ARGS[@]}"
