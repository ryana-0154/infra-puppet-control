# OpenTelemetry Collector Setup

This document describes the OpenTelemetry Collector configuration for monitoring Claude Code usage in your infrastructure.

## Overview

The OTEL Collector setup provides:
- **Metrics collection** from Claude Code CLI
- **Prometheus integration** for data storage
- **Grafana dashboards** for visualization
- **Cost tracking** and token usage monitoring
- **Performance analytics** and cache efficiency metrics

## Architecture

```
Claude Code CLI → OTEL Collector → Prometheus → Grafana
```

The collector receives telemetry data via gRPC/HTTP and exports metrics to Prometheus for scraping.

## Configuration

### Puppet Profile

The `profile::otel_collector` class manages the complete OTEL setup:

```yaml
# Enable OTEL Collector
manage_otel_collector: true
profile::otel_collector::manage_otel_collector: true

# Directory and ports
profile::otel_collector::otel_dir: '/opt/otel'
profile::otel_collector::otel_grpc_port: 4317
profile::otel_collector::otel_http_port: 4318
profile::otel_collector::otel_prometheus_port: 8889

# Container image
profile::otel_collector::otel_collector_image: 'otel/opentelemetry-collector-contrib:0.91.0'

# Grafana dashboards
profile::otel_collector::enable_grafana_dashboards: true
```

### Firewall Rules

OTEL ports are restricted to the WireGuard network for security:

```yaml
profile::firewall::custom_rules:
  otel_grpc:
    port: 4317
    proto: tcp
    source: '10.10.10.0/24'  # WireGuard network only
    jump: accept
  otel_prometheus:
    port: 8889
    proto: tcp
    source: '10.10.10.0/24'  # For Prometheus scraping
    jump: accept
```

## Claude Code Configuration

To send metrics to the OTEL Collector, configure these environment variables:

```bash
# OTEL endpoint (replace with your server IP)
export OTEL_EXPORTER_OTLP_ENDPOINT=http://10.10.10.1:4317

# Service identification
export OTEL_SERVICE_NAME=claude-code
export OTEL_RESOURCE_ATTRIBUTES="service.version=1.0.0,environment=production"

# Optional: Enable detailed metrics
export OTEL_METRICS_EXPORTER=otlp
export OTEL_TRACES_EXPORTER=otlp
export OTEL_LOGS_EXPORTER=otlp
```

## Prometheus Integration

Add this job to your Prometheus configuration:

```yaml
scrape_configs:
  - job_name: 'otel-collector'
    static_configs:
      - targets: ['localhost:8889']
    scrape_interval: 15s
    metrics_path: /metrics
    honor_labels: true
```

## Grafana Dashboards

Two dashboards are automatically created:

### Claude Code Overview
- Total sessions and token usage
- Cost tracking by model
- Cache hit rate
- Token usage trends

### Claude Code Cost Analysis
- Daily cost trends
- Model cost breakdown
- Token cost efficiency
- Cache savings analysis
- Hourly usage patterns

## Service Management

The OTEL Collector runs as a systemd service:

```bash
# Service management
sudo systemctl status otel-collector
sudo systemctl restart otel-collector
sudo systemctl logs -f otel-collector

# Docker management
cd /opt/otel
sudo docker-compose ps
sudo docker-compose logs -f
```

## Monitoring and Troubleshooting

### Health Checks

The collector provides health endpoints:
- Health: `http://localhost:13133`
- Metrics: `http://localhost:8889/metrics`
- Profiling: `http://localhost:1777/debug/pprof`

### Log Analysis

Check collector logs:
```bash
sudo docker-compose -f /opt/otel/docker-compose.yaml logs otel-collector
```

Common issues:
- **Connection refused**: Check firewall rules and network connectivity
- **High memory usage**: Adjust GOMEMLIMIT in the container
- **Missing metrics**: Verify Claude Code OTEL configuration

### Performance Tuning

Key configuration options in `otel-collector-config.yaml`:
- `batch.timeout`: Metric batching interval
- `memory_limiter.limit_mib`: Memory limit for the collector
- `prometheus.const_labels`: Additional labels for metrics

## Security Considerations

1. **Network access**: OTEL ports restricted to WireGuard network
2. **Authentication**: Consider adding API keys for production
3. **Data retention**: Configure Prometheus retention policies
4. **Log rotation**: Container logs are automatically rotated
5. **Resource limits**: Memory limits prevent resource exhaustion

## Metrics Reference

Key metrics exported by Claude Code:

| Metric | Type | Description |
|--------|------|-------------|
| `claude_sessions_total` | Counter | Total Claude Code sessions |
| `claude_tokens_total` | Counter | Total tokens processed |
| `claude_cost_usd_total` | Counter | Total cost in USD |
| `claude_cache_hits_total` | Counter | Cache hit count |
| `claude_cache_misses_total` | Counter | Cache miss count |
| `claude_cache_tokens_saved_total` | Counter | Tokens saved by cache |
| `claude_cache_cost_saved_usd_total` | Counter | Cost saved by cache |

All metrics include labels for:
- `model`: Claude model used (opus, sonnet, haiku)
- `service_name`: Service identifier
- `service_version`: Version information
