# Gorchain stack

Gorchain RPC node stack.

## Deployment

```bash
laconic-so --stack ./stack-orchestrator/stacks/gorchain-rpc deploy create \
  --spec-file spec.yml \
  --deployment-dir ./deployment
```

The stack uses Caddy for HTTPS proxy with automatic certificate management.
For development, it uses self-signed certificates by default. For production with Let's Encrypt, refer to configuration below.

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
- `FAUCET_ADDRESS`: (Optional) TCP address of a faucet service to enable `requestAirdrop` RPC support.
- `CADDY_DOMAIN`: Domain name for HTTPS (eg. `rpc.yourdomain.com`) (default: `localhost`)
- `CADDY_TLS_CONFIG`: Set to `""` for production (uses Let's Encrypt) (default: `tls internal`, uses self-signed certs for dev)
- `CADDY_ACME_EMAIL`: Email for Let's Encrypt certificates, required in production (eg. `admin@yourdomain.com`)

### Automatic restarts

The stack includes a `restarter` service that periodically restarts nodes to mitigate probable
memory leaks and ensure stability. By default:
- Validator: restarts every 4 hours at :00
- RPC node: restarts every 6 hours at :30 (staggered to avoid simultaneous restarts)

Edit deployment `config/gorchain/restart.cron` to customize the restart schedules.

## Notes

- Metrics are exported to InfluxDB (if gorchain-monitoring stack is running).
