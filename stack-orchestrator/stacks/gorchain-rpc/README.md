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
<!-- TODO finish -->

- `CLUSTER_TYPE`: Network type (default: testnet)
- `RUST_LOG`: Log level
- `FAUCET_LAMPORTS`: Amount distributed by faucet
- `ENABLE_FAUCET`: Enable/disable faucet
- `RPC_PORT`, `RPC_WS_PORT`: RPC and websocket pubsub ports
- `GOSSIP_PORT`
- `VALIDATOR_ENTRYPOINT`
- `SOLANA_METRICS_CONFIG`: Metrics output config. To output to `gorchain-monitoring` influxdb, set
  to `host=http://influxdb:8086,db=agave_metrics,u=admin,p=admin`.

### Automatic restarts

The stack includes a `restarter` service that periodically restarts nodes to mitigate probable
memory leaks and ensure stability. By default:
- Validator: restarts every 4 hours at :00
- RPC node: restarts every 6 hours at :30 (staggered to avoid simultaneous restarts)

Edit deployment `config/gorchain/restart.cron` to customize the restart schedules.

## Ports
<!-- TODO -->

- `8899`: RPC JSON
- `8900`: RPC pubsub
- `8001/udp`: Gossip

- `443`: HTTPS (via Envoy)
- `80`: HTTP redirect
- `9901`: Envoy admin

## Notes

- Metrics are exported to InfluxDB (if gorchain-monitoring stack is running).
