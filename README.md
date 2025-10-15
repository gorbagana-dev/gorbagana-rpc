# Gorchain stacks

[Stack-orchestrator](https://github.com/cerc-io/stack-orchestrator) definitions for deploying Gorchain validator and monitoring infrastructure.

## Stacks

- **gorchain**: Validator node with RPC endpoints and faucet
- **gorchain-monitoring**: Metrics collection and visualization (InfluxDB + Grafana)

## Quick start

```bash
export CERC_REPO_BASE_DIR=~/repos

# 1. Fetch this stack repository
git clone git@github.com:gorbagana-dev/gorchain-stacks.git ~/
# Locate the stack definitions
stacks=~/gorchain-stacks/stack-orchestrator/stacks

# 2. Deploy gorchain validator:
# Clone repositories into $CERC_REPO_BASE_DIR
laconic-so --stack $stacks/gorchain setup-repositories
# Build all needed images
laconic-so --stack $stacks/gorchain build-containers
# Start all services
laconic-so --stack $stacks/gorchain deploy up

# 3. Deploy monitoring (optional)
laconic-so --stack $stacks/gorchain-monitoring build-containers
laconic-so --stack $stacks/gorchain-monitoring deploy up
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
