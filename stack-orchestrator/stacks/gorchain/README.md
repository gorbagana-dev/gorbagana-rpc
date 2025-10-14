# Gorchain stack

Gorchain validator node stack (Agave/Solana fork).

## Configuration

- `CLUSTER_TYPE`: Network type (default: testnet)
- `RUST_LOG`: Log level
- `FAUCET_LAMPORTS`: Amount distributed by faucet
- `ENABLE_FAUCET`: Enable/disable faucet

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

- The validator requires TLS certificates for Envoy proxy. Mount these in the envoy-proxy service volumes.
- Metrics are exported to InfluxDB (if gorchain-monitoring stack is running).
