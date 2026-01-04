# Grafana Cloud Migration - Foreman Configuration Guide

This guide shows you how to configure the Grafana Cloud migration using **Foreman Host/Hostgroup Parameters** instead of Hiera.

## Why Foreman Parameters?

Since we're using the **roles & profiles pattern**, classes are included via roles rather than directly assigned. This means:
- ❌ **Smart Class Parameters DON'T work** (they only work with directly assigned classes)
- ✅ **Host/Hostgroup Parameters DO work** (they become top-scope variables)

The code now uses multi-source parameter resolution:
1. **Foreman Host/Hostgroup Parameters** (highest priority)
2. Hiera data (middle priority)
3. Class defaults (lowest priority)

---

## Step-by-Step Configuration in Foreman

### Step 1: Navigate to Host Parameters

1. Log into Foreman web UI
2. Go to **Hosts** → **All Hosts**
3. Click on **vps.ra-home.co.uk**
4. Click the **Parameters** tab

### Step 2: Add Grafana Cloud Parameters

Click **+ Add Parameter** for each of the following:

#### Enable Grafana Cloud
- **Name**: `monitoring_enable_grafana_cloud`
- **Type**: `boolean`
- **Value**: `true`

#### Select Metrics Agent
- **Name**: `monitoring_metrics_agent`
- **Type**: `string`
- **Value**: `alloy`

#### Grafana Cloud Metrics URL
- **Name**: `monitoring_grafana_cloud_metrics_url`
- **Type**: `string`
- **Value**: `https://prometheus-prod-XX-prod-YY-ZZZ.grafana.net/api/prom/push`
  - (Replace with your actual Prometheus endpoint from Grafana Cloud)

#### Grafana Cloud Metrics Username
- **Name**: `monitoring_grafana_cloud_metrics_username`
- **Type**: `string`
- **Value**: `123456`
  - (Replace with your Instance ID from Grafana Cloud)

#### Grafana Cloud Metrics API Key
- **Name**: `monitoring_grafana_cloud_metrics_api_key`
- **Type**: `string`
- **Value**: `glc_XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX`
  - (Your Grafana Cloud API token)
  - ⚠️ **IMPORTANT**: Click **Hidden Value** checkbox to encrypt this!

#### Grafana Cloud Logs URL
- **Name**: `monitoring_grafana_cloud_logs_url`
- **Type**: `string`
- **Value**: `https://logs-prod-XXX.grafana.net/loki/api/v1/push`
  - (Replace with your Loki endpoint from Grafana Cloud)

#### Grafana Cloud Logs Username
- **Name**: `monitoring_grafana_cloud_logs_username`
- **Type**: `string`
- **Value**: `654321`
  - (Replace with your Logs User ID from Grafana Cloud)

#### Grafana Cloud Logs API Key
- **Name**: `monitoring_grafana_cloud_logs_api_key`
- **Type**: `string`
- **Value**: `glc_XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX`
  - (Same API token as metrics, or create a separate one)
  - ⚠️ **IMPORTANT**: Click **Hidden Value** checkbox to encrypt this!

### Step 3: Disable Local Storage Services (Optional but Recommended)

To save resources (~60-70% RAM reduction), disable the local monitoring stack:

#### Disable VictoriaMetrics
- **Name**: `monitoring_enable_victoriametrics`
- **Type**: `boolean`
- **Value**: `false`

#### Disable Loki
- **Name**: `monitoring_enable_loki`
- **Type**: `boolean`
- **Value**: `false`

#### Disable Grafana
- **Name**: `monitoring_enable_grafana`
- **Type**: `boolean`
- **Value**: `false`

#### Disable Authelia (SSO - not needed for cloud)
- **Name**: `monitoring_enable_authelia`
- **Type**: `boolean`
- **Value**: `false`

#### Disable Nginx Proxy (not needed for cloud)
- **Name**: `monitoring_enable_nginx_proxy`
- **Type**: `boolean`
- **Value**: `false`

#### Disable Redis (not needed for cloud)
- **Name**: `monitoring_enable_redis`
- **Type**: `boolean`
- **Value**: `false`

### Step 4: Configure OTEL Collector for Traces

If you want to send traces to Grafana Cloud Tempo:

#### Enable Tempo
- **Name**: `otel_enable_grafana_cloud_tempo`
- **Type**: `boolean`
- **Value**: `true`

#### Tempo Endpoint
- **Name**: `otel_grafana_cloud_tempo_endpoint`
- **Type**: `string`
- **Value**: `https://tempo-prod-XX-prod-YY-ZZZ.grafana.net/tempo`

#### Tempo Username
- **Name**: `otel_grafana_cloud_tempo_username`
- **Type**: `string`
- **Value**: `654321`
  - (Same as Logs username)

#### Tempo API Key
- **Name**: `otel_grafana_cloud_tempo_api_key`
- **Type**: `string`
- **Value**: `glc_XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX`
  - ⚠️ **IMPORTANT**: Click **Hidden Value** checkbox!

#### Tempo Protocol
- **Name**: `otel_tempo_protocol`
- **Type**: `string`
- **Value**: `otlphttp`

---

## Step 5: Deploy Configuration

### Option A: Trigger Puppet Run from Foreman

1. In Foreman, go to **Hosts** → **All Hosts**
2. Click on **vps.ra-home.co.uk**
3. Click **Run Puppet** button in top-right

### Option B: SSH and Run Puppet Manually

```bash
ssh vps.ra-home.co.uk
sudo puppet agent -t
```

---

## Step 6: Verify Deployment

### Check Alloy Container

```bash
ssh vps.ra-home.co.uk

# Should see 'alloy' container running
docker ps | grep alloy

# Check Alloy logs for successful startup
docker logs alloy

# Look for successful remote_write messages
docker logs alloy 2>&1 | grep -i "remote_write\|loki"
```

### Check What's NOT Running (Good!)

```bash
# These should NOT be running anymore (saves RAM)
docker ps | grep -E "victoriametrics|loki|grafana|authelia|nginx-proxy|redis"
```

If these are still running, Puppet might not have applied the changes yet.

---

## Alternative: Using Hostgroup Parameters

If you have multiple hosts that should use the same configuration, use **Hostgroup Parameters** instead:

1. Go to **Configure** → **Host Groups**
2. Select your hostgroup (or create one)
3. Go to **Parameters** tab
4. Add the same parameters as above

All hosts in that hostgroup will inherit these parameters.

---

## Verification Checklist

- [ ] All Foreman parameters added
- [ ] API keys marked as **Hidden Value**
- [ ] Puppet run completed successfully
- [ ] Alloy container is running
- [ ] Old containers (victoriametrics, loki, grafana) are stopped
- [ ] Metrics appearing in Grafana Cloud (check Explore → Prometheus → query `up`)
- [ ] Logs appearing in Grafana Cloud (check Explore → Loki → query `{job="varlogs"}`)
- [ ] Traces appearing in Grafana Cloud Tempo (if OTEL configured)

---

## Troubleshooting

### Parameters Not Taking Effect

If Puppet runs but parameters aren't applied:

1. **Check parameter names** - They must match exactly (case-sensitive!)
2. **Verify parameter types** - Boolean values must be boolean type, not string "true"
3. **Check Puppet logs**:
   ```bash
   ssh vps.ra-home.co.uk
   sudo tail -f /var/log/puppet/puppet.log
   ```

### API Key Not Working

If you get 401 errors in Alloy logs:

1. Verify the API token in Grafana Cloud → Access Policies → Tokens
2. Ensure token has scopes: `metrics:write`, `logs:write`, `traces:write`
3. Make sure you clicked **Hidden Value** in Foreman (it encrypts the value)
4. Try regenerating the token in Grafana Cloud

### Alloy Container Won't Start

```bash
# Check Alloy config syntax
docker run --rm -v /opt/monitoring:/etc/alloy:ro grafana/alloy:latest \
  run --config.file=/etc/alloy/alloy-config.alloy --dry-run

# Check detailed logs
docker logs alloy 2>&1 | less
```

---

## Comparison: Foreman vs Hiera

| Feature | Foreman Parameters | Hiera |
|---------|-------------------|-------|
| Configuration Location | Web UI | YAML files in `data/` |
| Version Control | ❌ Not in git | ✅ Tracked in git |
| Encryption | ✅ Built-in (Hidden Value) | ✅ eyaml |
| Per-Host Config | ✅ Easy | ✅ Requires file per host |
| Priority | 🥇 Highest | 🥈 Middle |
| Best For | Secrets, per-host overrides | Default configs, version-controlled settings |

**Recommendation**: Use Foreman for secrets (API keys) and per-host overrides, use Hiera for defaults and version-controlled configuration.

---

## Next Steps

After successful deployment:

1. **Import Dashboards** in Grafana Cloud:
   - Node Exporter Full: Dashboard ID `1860`
   - Docker Monitoring: Dashboard ID `893`
   - Loki Logs: Dashboard ID `13639`

2. **Monitor for 24 hours** to ensure stability

3. **Clean up old volumes** (after 7 days):
   ```bash
   docker volume rm monitoring_victoriametrics-data
   docker volume rm monitoring_loki-data
   docker volume rm monitoring_grafana-data
   ```

---

## Support

If you encounter issues:

1. Check Puppet logs: `/var/log/puppet/puppet.log`
2. Check Alloy logs: `docker logs alloy`
3. Verify parameters in Foreman UI match exactly
4. Run Puppet in debug mode: `sudo puppet agent -t --debug`
