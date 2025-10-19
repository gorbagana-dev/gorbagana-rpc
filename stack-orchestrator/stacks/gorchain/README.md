# Gorchain stack

Gorchain validator node stack (Agave/Solana fork).

> [!WARNING]
> A TLS certificate is required for the Envoy proxy. When running an ephemeral cluster with `deploy
> up`, the envoy container will use a default self-signed certificate.  This is a placeholder for
> development purposes; for production, use certificates from a trusted CA.

## Deployment

This stack has a custom `create` command that requires SSL certificate files:

```bash
laconic-so --stack ./stack-orchestrator/stacks/gorchain deploy create \
  --spec-file spec.yml \
  --deployment-dir ./deployment \
  -- \
  --certificate-file /path/to/cert.pem \
  --private-key-file /path/to/privkey.pem
```

The certificate and private key files are copied to the deployment config directory and mounted into the Envoy proxy container for HTTPS support.

## Configuration

- `CLUSTER_TYPE`: Network type (default: testnet)
- `RUST_LOG`: Log level
- `FAUCET_LAMPORTS`: Amount distributed by faucet
- `ENABLE_FAUCET`: Enable/disable faucet
- `RESTART_INTERVAL_SECONDS`: Time between automatic validator restarts (default: 4 hours)

## Ports

- `8899`: RPC JSON
- `8900`: RPC pubsub
- `8001/udp`: Gossip
- `8003/udp`: TPU
- `9900`: Faucet
- `443`: HTTPS (via Envoy)
- `80`: HTTP redirect
- `9901`: Envoy admin

## Notes

- Metrics are exported to InfluxDB (if gorchain-monitoring stack is running).
