# Gorbagana Gorchain Base Image

This is the base image for all Gorchain containers. It contains:

- Complete build stage with all Agave/Solana binaries compiled
- Runtime environment with all dependencies installed
- All common binaries: `agave-validator`, `solana-keygen`, `solana-genesis`, `solana-faucet`, `solana`
- User setup and directory structure

## Derived Images

The following images derive from this base:

- `gorbagana/gorchain-validator`: Validator node with genesis files and precompiled programs
- `gorbagana/gorchain-rpc`: RPC-only node (no genesis files)

## Build Order

This base image MUST be built before any derived images:

```bash
laconic-so build-containers --include gorbagana/gorchain-base
laconic-so build-containers --include gorbagana/gorchain-validator
laconic-so build-containers --include gorbagana/gorchain-rpc
```

Or build all at once (stack orchestrator handles dependencies):

```bash
laconic-so build-containers --include gorbagana/gorchain-base,gorbagana/gorchain-validator,gorbagana/gorchain-rpc
```
