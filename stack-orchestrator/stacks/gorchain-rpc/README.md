# Gorchain stack

Gorchain RPC node stack.

> [!WARNING]
> A TLS certificate is required for the Envoy proxy. When running an ephemeral cluster with `deploy
> up`, the envoy container will use a default self-signed certificate.  This is a placeholder for
> development purposes; for production, use certificates from a trusted CA.

## Deployment

This stack has a custom `create` command that requires SSL certificate files:

```bash
laconic-so --stack ./stack-orchestrator/stacks/gorchain-rpc deploy create \
  --spec-file spec.yml \
  --deployment-dir ./deployment \
  -- \
  --certificate-file /path/to/cert.pem \
  --private-key-file /path/to/privkey.pem
```

The certificate and private key files are copied to the deployment config directory and mounted into the Envoy proxy container for HTTPS support.

## Configuration

Main environment variables (refer to compose file for authoritative reference and default values):

The usage for these variables is the same as in the [voting validator stack](../gorchain/README.md):

- `CLUSTER_TYPE`
- `RUST_LOG`
- `RPC_PORT`
- `RPC_WS_PORT`
- `GOSSIP_PORT`
- `DYNAMIC_PORT_RANGE`
- `SOLANA_METRICS_CONFIG`

Additionally:

- `VALIDATOR_ENTRYPOINT`: Gossip for cluster
- `PUBLIC_RPC_ADDRESS`: RPC address advertised to cluster over gossip. If this is not set, Agave will be started as a `--private-rpc` node, and will not advertise its RPC address or accept incoming RPC connections.
- `ENVOY_HTTPS_PORT`, `ENVOY_HTTP_PORT`: Host ports for Envoy to listen on
- `FAUCET_ADDRESS`: (Optional) TCP address of a faucet service to enable `requestAirdrop` RPC support.

### Automatic restarts

The stack includes a `restarter` service that periodically restarts nodes to mitigate probable
memory leaks and ensure stability. By default:
- Validator: restarts every 4 hours at :00
- RPC node: restarts every 6 hours at :30 (staggered to avoid simultaneous restarts)

Edit deployment `config/gorchain/restart.cron` to customize the restart schedules.

## Notes

- Metrics are exported to InfluxDB (if gorchain-monitoring stack is running).
