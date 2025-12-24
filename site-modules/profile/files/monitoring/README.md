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
- Loki API: `http://<monitoring_ip>:3100`
- Promtail: `http://<monitoring_ip>:9080`
- Node Exporter metrics: `http://<monitoring_ip>:9100/metrics`

## Loki Log Aggregation

### Overview
Loki is a horizontally-scalable, highly-available log aggregation system inspired by Prometheus. It indexes metadata (labels) rather than full-text, making it more efficient and cost-effective for log storage.

### Log Sources

Promtail automatically collects logs from:

1. **System Logs**
   - `/var/log/*log` - General system logs
   - `/var/log/syslog` - System log messages
   - `/var/log/auth.log` (Debian/Ubuntu) - Authentication logs
   - `/var/log/secure` (RedHat/Rocky/AlmaLinux) - Authentication logs

2. **Security Logs**
   - `/var/log/fail2ban.log` - Fail2ban intrusion prevention logs (with jail and level labels)

3. **Configuration Management**
   - `/var/log/puppetlabs/puppet/*.log` - Puppet agent logs

4. **Web Server Logs**
   - `/var/log/nginx/*access.log` - Nginx access logs (with method and status labels)
   - `/var/log/nginx/*error.log` - Nginx error logs (with level labels)
   - `/var/log/apache2/*access*.log` - Apache access logs
   - `/var/log/apache2/*error*.log` - Apache error logs

5. **Container Logs**
   - `/var/lib/docker/containers/*/*log` - Docker container logs (parsed JSON format)

6. **Systemd Journal**
   - System journal logs with unit, priority, and nodename labels

### Retention and Performance

- **Default Retention**: 7 days (168 hours)
- **Storage Backend**: TSDB (v12 schema) for better performance
- **Compaction**: Runs every 10 minutes to clean up old logs
- **Query Cache**: 500MB embedded cache with 24h TTL
- **Rate Limits**: 4MB/s ingestion rate with 6MB bursts

To adjust retention, modify `limits_config.retention_period` in the Loki configuration.

### LogQL Query Examples

Access Grafana's Explore interface and use the Loki datasource to run queries:

#### Basic Queries

```logql
# All logs from fail2ban
{job="fail2ban"}

# All authentication logs
{log_type="authentication"}

# Nginx error logs only
{job="nginx", log_type="error"}

# Docker container logs
{job="docker"}

# Specific systemd unit
{job="systemd-journal", unit="ssh.service"}
```

#### Filtered Queries

```logql
# Failed SSH login attempts
{job="auth"} |= "Failed password"

# Nginx 404 errors
{job="nginx", log_type="access", status="404"}

# Fail2ban bans (any jail)
{job="fail2ban"} |= "Ban"

# Error level logs from nginx
{job="nginx", log_type="error", level="error"}

# Puppet errors
{job="puppet"} |= "Error:"
```

#### Aggregation Queries

```logql
# Count of failed SSH attempts over time
sum(count_over_time({job="auth"} |= "Failed password" [5m]))

# Rate of Nginx requests per second
rate({job="nginx", log_type="access"}[1m])

# Count of bans by fail2ban jail
sum by (jail) (count_over_time({job="fail2ban"} |= "Ban" [1h]))

# Error rate for nginx
sum(rate({job="nginx", log_type="error"}[5m])) by (level)
```

#### Pattern Extraction

```logql
# Extract IP addresses from auth logs
{job="auth"} |= "Failed password" | pattern `<_> from <ip> port`

# Parse nginx access logs for specific paths
{job="nginx", log_type="access"} | json | line_format "{{.method}} {{.path}} - {{.status}}"

# Extract fail2ban jail names
{job="fail2ban"} | regexp `jail: (?P<jail_name>\w+)`
```

### Alerts (Optional)

Loki can send alerts to Prometheus Alertmanager. Create alert rules in `/loki/rules/` directory:

```yaml
groups:
  - name: security_alerts
    interval: 1m
    rules:
      - alert: HighFailedSSHAttempts
        expr: |
          sum(count_over_time({job="auth"} |= "Failed password" [5m])) > 10
        labels:
          severity: warning
        annotations:
          summary: "High number of failed SSH attempts detected"
```

## Troubleshooting

### General Issues

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

### Loki-Specific Issues

1. **No logs appearing in Grafana**:
   - Check Promtail is running: `docker-compose ps promtail`
   - Verify Promtail can reach Loki: `docker-compose logs promtail | grep error`
   - Check log file permissions: Promtail runs as root but may need access

2. **High memory usage**:
   - Reduce `limits_config.max_query_parallelism` in loki-config.yaml
   - Decrease `query_range.results_cache.max_size_mb`
   - Reduce retention period

3. **Slow queries**:
   - Add more specific labels to your queries
   - Reduce query time range
   - Use `|= "filter"` before regex or json parsing
   - Check `max_query_length` and `max_chunks_per_query` limits

4. **Promtail not collecting logs**:
   - Verify log file paths exist on the host
   - Check Promtail positions file: `docker exec promtail cat /tmp/positions.yaml`
   - Ensure log files are readable (for web server logs, check permissions)

5. **Check Loki health**:
   ```bash
   curl http://<monitoring_ip>:3100/ready
   curl http://<monitoring_ip>:3100/metrics
   ```

### Performance Tuning

For high-volume log environments:
1. Increase `limits_config.ingestion_rate_mb` and `ingestion_burst_size_mb`
2. Adjust `compaction_interval` based on disk I/O capacity
3. Consider using object storage (S3, GCS) instead of filesystem for production
4. Use bloom filters for better query performance (requires external storage)

## Backup and Recovery

### Backing up Loki Data

Loki data is stored in the Docker volume `loki-data`. To backup:

```bash
# Stop Loki
docker-compose stop loki

# Backup the volume
docker run --rm -v monitoring_loki-data:/data -v $(pwd):/backup \
  alpine tar czf /backup/loki-backup-$(date +%Y%m%d).tar.gz -C /data .

# Start Loki
docker-compose start loki
```

### Restoring Loki Data

```bash
# Stop Loki
docker-compose stop loki

# Restore the volume
docker run --rm -v monitoring_loki-data:/data -v $(pwd):/backup \
  alpine sh -c "cd /data && tar xzf /backup/loki-backup-YYYYMMDD.tar.gz"

# Start Loki
docker-compose start loki
```
