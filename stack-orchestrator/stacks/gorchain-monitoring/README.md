# Gorchain monitoring stack

Monitoring infrastructure for Gorchain using InfluxDB and Grafana.

## Services

- `influxdb`: Time-series database for metrics storage
- `grafana`: Visualization dashboard

## Configuration

- InfluxDB credentials (default: admin/admin)
- Grafana admin credentials (default: admin/admin)

## Access

- Grafana: http://localhost:3001
- InfluxDB: http://localhost:8086

Default credentials for both:
- Username: `admin`
- Password: `admin`

## Notes

- This stack connects to the `gorchain` network created by the gorchain stack
- Grafana dashboards are pre-configured in `../config/gorchain-monitoring/grafana/dashboards/`
- Change default passwords in production deployments
