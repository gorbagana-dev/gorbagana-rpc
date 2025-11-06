# Gorchain stack

Gorchain voting validator node stack.

## Deployment

```bash
laconic-so --stack ./stack-orchestrator/stacks/gorchain deploy create \
  --spec-file spec.yml \
  --deployment-dir ./deployment
```

## Configuration

Main environment variables (refer to compose file for authoritative reference and default values):

- `CLUSTER_TYPE`: Network type (default: testnet)
- `RUST_LOG`: Log level
- `FAUCET_LAMPORTS`: Amount distributed by faucet
- `ENABLE_FAUCET`: Enable/disable faucet
- `RPC_PORT`, `RPC_WS_PORT`: RPC and websocket pubsub ports
- `GOSSIP_PORT`: Gossip port for TCP and UDP traffic
- `DYNAMIC_PORT_RANGE`: Range of dynamically assigned ports for various gossip protocols
- `PUBLIC_RPC_ADDRESS`: RPC address advertised to cluster over gossip
- `PUBLIC_GOSSIP_HOST`: Gossip address advertised to cluster
- `SOLANA_METRICS_CONFIG`: Metrics output config. To output to `gorchain-monitoring` influxdb, set
  to `host=http://influxdb:8086,db=agave_metrics,u=admin,p=admin`.

### Automatic restarts

The stack includes a `restarter` service that periodically restarts nodes to mitigate probable
memory leaks and ensure stability. By default:
- Validator: restarts every 4 hours at :00
- RPC node: restarts every 6 hours at :30 (staggered to avoid simultaneous restarts)

Edit deployment `config/gorchain/restart.cron` to customize the restart schedules.

### Faucet Configuration

To enable token airdrops via the `requestAirdrop` RPC method, enable the faucet service with `ENABLE_FAUCET=true`.  This can also be made accessible from an RPC node by setting `FAUCET_ADDRESS` to point to this service: see [the RPC stack](../gorchain/README.md). The service's port is currently hardcoded to `9900`.

The RPC node will forward airdrop requests (`requestAirdrop`) to the faucet service via TCP, receive a signed transaction, and submit it to the chain. Therefore, the port does not to be accessible except to the RPC nodes directly using it.

## Notes

- Metrics are exported to InfluxDB (if gorchain-monitoring stack is running).
