# Monitoring Stack Configuration

This directory contains the configuration for a Docker Compose-based monitoring stack managed by Puppet.

## Components

The monitoring stack can include the following services:
- **Prometheus** - Metrics collection and storage
- **Grafana** - Metrics visualization
- **Loki** - Log aggregation
- **Promtail** - Log collection agent
- **Node Exporter** - System metrics exporter
- **Blackbox Exporter** - Probe-based monitoring
- **PiHole Exporter** - PiHole metrics (if using PiHole)
- **WireGuard Portal** - WireGuard VPN management UI

## Configuration

All configuration is managed through Puppet Hiera. Key parameters include:

### Network Configuration
- `profile::monitoring::monitoring_ip` - IP address services will bind to
- `profile::monitoring::prometheus_port` - Prometheus port (default: 9090)
- `profile::monitoring::grafana_port` - Grafana port (default: 3000)

### Service Management
Enable/disable individual services:
- `profile::monitoring::enable_prometheus`
- `profile::monitoring::enable_grafana`
- `profile::monitoring::enable_loki`
- etc.

### Image Versions
Control specific image versions for stability:
- `profile::monitoring::prometheus_image`
- `profile::monitoring::grafana_image`
- etc.

### Secrets
Sensitive data should be encrypted with eyaml:
- `profile::monitoring::grafana_admin_password`
- `profile::monitoring::pihole_password`
- `profile::monitoring::pihole_api_token`

## Usage

1. Configure the monitoring stack in Hiera (see `data/examples/monitoring-example.yaml`)
2. Apply the Puppet configuration
3. Start the services:
   ```bash
   cd /opt/monitoring
   docker-compose up -d
   ```

## Security Notes

- Secrets are stored in files with 0600 permissions in the `secrets/` directory
- The docker-compose.yaml file is generated from a template - do not edit directly
- Always encrypt sensitive values using hiera-eyaml before committing to git

## Accessing Services

After deployment:
- Prometheus: `http://<monitoring_ip>:<prometheus_port>`
- Grafana: `http://<monitoring_ip>:<grafana_port>`
- Node Exporter metrics: `http://<monitoring_ip>:9100/metrics`

## Troubleshooting

1. Check service logs:
   ```bash
   docker-compose logs <service_name>
   ```

2. Verify configuration was applied:
   ```bash
   puppet agent -t
   ```

3. Check generated docker-compose.yaml:
   ```bash
   cat /opt/monitoring/docker-compose.yaml
   ```
