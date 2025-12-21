# Monitoring Stack Deployment Guide

This guide covers deploying the templated Docker Compose monitoring stack managed by Puppet.

## Prerequisites

1. **Docker and Docker Compose** installed on target nodes
2. **Puppet agent** configured and running
3. **Network connectivity** between monitoring services
4. **Sufficient resources** for enabled services

## Deployment Steps

### 1. Configure Hiera Data

Create node-specific configuration in `data/nodes/<fqdn>.yaml`:

```yaml
# Basic configuration
profile::monitoring::manage_monitoring: true
profile::monitoring::monitoring_dir: '/opt/monitoring'
profile::monitoring::monitoring_ip: '0.0.0.0'  # Listen on all interfaces

# Enable/disable services based on resources
profile::monitoring::enable_prometheus: true
profile::monitoring::enable_grafana: true      # Requires 512MB+ RAM
profile::monitoring::enable_loki: true         # Requires 256MB+ RAM
profile::monitoring::enable_promtail: true
profile::monitoring::enable_blackbox: true
profile::monitoring::enable_node_exporter: true
profile::monitoring::enable_pihole_exporter: false  # Only if using PiHole
profile::monitoring::enable_wg_portal: false        # Only if using WireGuard

# Use specific image versions for stability
profile::monitoring::prometheus_image: 'prom/prometheus:v2.45.0'
profile::monitoring::grafana_image: 'grafana/grafana:10.0.0'
profile::monitoring::loki_image: 'grafana/loki:3.1.1'
```

### 2. Configure Secrets (Optional)

For services requiring authentication, encrypt passwords with eyaml:

```bash
# Generate encrypted values
eyaml encrypt -s 'your-grafana-admin-password'
eyaml encrypt -s 'your-pihole-password'
```

Add to Hiera:
```yaml
profile::monitoring::grafana_admin_password: >
  ENC[PKCS7,MIIBeQYJKoZIhvcNAQcDoIIBajCCAWYCAQAxggEhMIIBHQIBADAFMAACAQEw...]

profile::monitoring::pihole_password: >
  ENC[PKCS7,MIIBeQYJKoZIhvcNAQcDoIIBajCCAWYCAQAxggEhMIIBHQIBADAFMAACAQEw...]
```

### 3. Apply Puppet Configuration

Run Puppet to generate configuration files:

```bash
# On the target node
puppet agent -t

# Or from Puppet server
mco puppet runonce -F fqdn=your-node.example.com
```

This creates:
- `/opt/monitoring/docker-compose.yaml`
- `/opt/monitoring/prometheus.yaml` (if Prometheus enabled)
- `/opt/monitoring/loki-config.yaml` (if Loki enabled)
- `/opt/monitoring/promtail-config.yaml` (if Promtail enabled)
- `/opt/monitoring/blackbox.yaml` (if Blackbox enabled)
- `/opt/monitoring/secrets/` (if secrets configured)

### 4. Start Services

```bash
cd /opt/monitoring

# Pull latest images
docker-compose pull

# Start services
docker-compose up -d

# Check status
docker-compose ps
docker-compose logs
```

### 5. Verify Deployment

**Prometheus (default port 9090):**
```bash
curl http://localhost:9090/api/v1/targets
```

**Grafana (default port 3000):**
```bash
curl http://localhost:3000/api/health
# Login: admin / <configured_password>
```

**Node Exporter (port 9100):**
```bash
curl http://localhost:9100/metrics
```

## Service Configuration

### Prometheus Targets

The generated `prometheus.yaml` includes:
- **prometheus**: Self-monitoring on configured port
- **node**: Node Exporter metrics (if enabled)
- **blackbox**: HTTP/HTTPS probes (if enabled)
- **pihole**: PiHole metrics (if enabled)

### Loki Log Sources

Promtail is configured to collect:
- **System logs**: `/var/log/*log`
- **Docker logs**: Container logs via Docker driver
- **systemd journal**: System service logs

### Blackbox Monitoring

Preconfigured probe modules:
- **http_2xx**: HTTP/HTTPS health checks
- **tcp_connect**: TCP port connectivity
- **icmp**: ICMP ping checks
- **ssh_banner**: SSH service checks

## Troubleshooting

### Service Won't Start

```bash
# Check container logs
docker-compose logs <service_name>

# Check configuration syntax
docker-compose config

# Verify file permissions
ls -la /opt/monitoring/
```

### Common Issues

**Config file not found:**
- Verify Puppet run completed successfully
- Check Hiera configuration for typos
- Ensure service is enabled in Hiera

**Permission denied:**
- Check file ownership: `chown -R root:root /opt/monitoring`
- Verify Docker daemon is running
- Check Docker group membership

**Port conflicts:**
- Verify ports aren't in use: `netstat -tlnp`
- Use different ports in Hiera configuration
- Check firewall rules

**Out of memory:**
- Disable resource-intensive services (Grafana, Loki)
- Monitor with `docker stats`
- Increase system resources

### Log Locations

- **Docker Compose logs**: `docker-compose logs`
- **Puppet logs**: `/var/log/puppet/puppet.log`
- **System logs**: `/var/log/syslog`

## Maintenance

### Updates

Renovate Bot automatically creates PRs for image updates. To manually update:

```bash
# Update Hiera with new image versions
git checkout -b update-monitoring-images
# Edit data/nodes/<fqdn>.yaml
git commit -m "Update monitoring image versions"

# Apply changes
puppet agent -t

# Recreate containers with new images
cd /opt/monitoring
docker-compose pull
docker-compose up -d
```

### Backup

Important files to backup:
- Hiera configuration files
- Grafana dashboards and settings
- Prometheus data (if persistence enabled)
- Private keys for eyaml decryption

### Monitoring

Monitor the monitoring stack itself:
- Prometheus targets health
- Container resource usage
- Log volume and retention
- Disk space utilization

## Advanced Configuration

### Custom Prometheus Rules

Add alerting rules:
```yaml
# In Hiera
profile::monitoring::prometheus_rules:
  high_cpu:
    expr: 'cpu_usage > 90'
    for: '5m'
    labels:
      severity: 'warning'
```

### External Integrations

Configure external endpoints:
```yaml
# Grafana LDAP, external Loki, etc.
profile::monitoring::grafana_ldap_enabled: true
profile::monitoring::external_loki_url: 'https://loki.example.com'
```

### Multi-Node Setup

For distributed monitoring:
1. Central Prometheus on monitoring server
2. Node exporters on all nodes
3. Centralized Grafana for visualization
4. Loki for centralized log aggregation

See `data/examples/monitoring-example.yaml` for comprehensive configuration options.
