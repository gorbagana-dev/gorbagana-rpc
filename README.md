# Gorchain stacks

[Stack-orchestrator](https://github.com/cerc-io/stack-orchestrator) definitions for deploying Gorchain validator and monitoring infrastructure.

## Stacks

- **gorchain**: Standalone voting validator node with Envoy proxy
- **gorchain-rpc**: Standalone RPC node
- **gorchain-monitoring**: Metrics collection and visualization (InfluxDB + Grafana)

## Quick start

This will create an ephemeral deployment with data in mounted volumes for development.

**Note:** this will use a self-signed development certificate by default. Create a persistent
deployment to use a trusted TLS cert.

```bash
export CERC_REPO_BASE_DIR=~/repos

# 1. Fetch this stack repository
git clone git@github.com:gorbagana-dev/gorchain-stacks.git ~/
# Locate the stack definitions
stacks=~/gorchain-stacks/stack-orchestrator/stacks

# 2. Build images:
# Clone repositories into $CERC_REPO_BASE_DIR
# (this can be skipped if gorchain repo is already cloned)
laconic-so --stack $stacks/gorchain setup-repositories
# Build all needed images
laconic-so --stack $stacks/gorchain build-containers

# 3. Start containers in background
laconic-so --stack $stacks/gorchain deploy up

# Deploy monitoring (optional)
laconic-so --stack $stacks/gorchain-monitoring build-containers
laconic-so --stack $stacks/gorchain-monitoring deploy up

# 4. Stop and destroy containers (optionally pass --delete-volumes)
laconic-so --stack $stacks/gorchain deploy down
laconic-so --stack $stacks/gorchain-monitoring deploy down
```

To create a persistent deployment with filesystem-mounted data:

```bash
# Instantiate a deployment spec based on the stack
laconic-so --stack $stacks/gorchain deploy init --output ./spec.yml

# Create a deployment directory from the spec
# Note: SSL certificate and private key files are required
laconic-so --stack $stacks/gorchain deploy create \
  --spec-file ./spec.yml \
  --deployment-dir ./deployment \
  -- \
  --certificate-file /path/to/cert.pem \
  --private-key-file /path/to/privkey.pem

# Start containers
laconic-so deployment --dir ./deployment start
# Stop containers
laconic-so deployment --dir ./deployment stop
```

## Testing

Run the included tests to verify stack deployment:

```bash
./tests/gorchain-stack/test.sh
```

The tests verify:
- Repository cloning and container building
- Deployment creation and startup
- Service health checks (RPC endpoints, monitoring services)
- Validator slot progression (chain is producing blocks)

## Documentation

See individual stack README files:
- [gorchain/README.md](stack-orchestrator/stacks/gorchain/README.md)
- [gorchain-monitoring/README.md](stack-orchestrator/stacks/gorchain-monitoring/README.md)

## Structure

```
stack-orchestrator/
├── stacks/              # Stack definitions
│   ├── gorchain/
│   └── gorchain-monitoring/
├── compose/             # Docker compose files
├── config/              # Configuration files
└── container-build/     # Image build scripts
```
