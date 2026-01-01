# Foreman Migration Plan: Pi → New VPS L

## Overview

Migrate Foreman ENC infrastructure from under-resourced Pi (2GB RAM) to new VPS L (4 cores, 8GB RAM, 240GB storage).

**Migration Window:** Requires ~2-3 hours with Foreman downtime. Puppet agents will queue reports but won't receive updated catalogs during migration.

---

## Pre-Migration Checklist

### 1. Provision New VPS

- [ ] Order VPS L from provider
- [ ] Record new VPS IP address: `___.___.___. ___`
- [ ] Configure VPS hostname: `foreman.ra-home.co.uk`
- [ ] Install base OS (Rocky Linux 9 recommended)
- [ ] Set up SSH key access
- [ ] Configure firewall to allow SSH from your IP

### 2. Update DNS Records

**Before migration:**
```bash
# Current DNS (check first)
dig pi.ra-home.co.uk +short
dig foreman.ra-home.co.uk +short  # May not exist yet

# Create DNS records (low TTL for easy rollback)
foreman.ra-home.co.uk  300  IN  A     <NEW_VPS_IP>
foreman-new.ra-home.co.uk  300  IN  A     <NEW_VPS_IP>  # Temporary testing alias
```

### 3. Backup Current Pi Data

**Critical backup items:**

```bash
# SSH into pi.ra-home.co.uk
ssh pi.ra-home.co.uk

# 1. PostgreSQL database backup
sudo -u postgres pg_dump foreman > /tmp/foreman_backup_$(date +%Y%m%d).sql
gzip /tmp/foreman_backup_*.sql

# 2. Foreman settings directory
sudo tar -czf /tmp/foreman_settings_$(date +%Y%m%d).tar.gz \
  /etc/foreman \
  /etc/foreman-proxy \
  /etc/puppetlabs/puppet \
  /var/lib/foreman

# 3. SSL certificates (if custom certs)
sudo tar -czf /tmp/foreman_ssl_$(date +%Y%m%d).tar.gz \
  /etc/pki/tls/certs/foreman* \
  /etc/pki/tls/private/foreman* \
  /etc/puppetlabs/puppet/ssl

# 4. Copy backups off-server
scp pi.ra-home.co.uk:/tmp/foreman_*.{sql.gz,tar.gz} ~/foreman-backups/
```

**Verify backups:**
```bash
ls -lh ~/foreman-backups/
# Should see:
# - foreman_backup_YYYYMMDD.sql.gz
# - foreman_settings_YYYYMMDD.tar.gz
# - foreman_ssl_YYYYMMDD.tar.gz
```

---

## Puppet Configuration Updates

### 1. Create New Node Configuration

Create `data/nodes/foreman.ra-home.co.uk.yaml`:

```yaml
---
# Node-specific configuration for foreman.ra-home.co.uk (Foreman ENC server)
# Migrated from pi.ra-home.co.uk

# Base profile settings
profile::base::manage_firewall: true
profile::base::manage_logrotate: true
profile::base::manage_unattended_upgrades: true
profile::base::manage_ssh_hardening: true

# PostgreSQL Database Configuration
profile::postgresql::manage_postgresql: true
profile::postgresql::postgres_version: '13'
profile::postgresql::listen_addresses: 'localhost'
profile::postgresql::port: 5432
profile::postgresql::manage_firewall: false  # localhost only, no external access
profile::postgresql::databases:
  foreman:
    owner: foreman
    encoding: UTF8
    locale: en_US.UTF-8
profile::postgresql::database_users:
  foreman:
    # TODO: Copy encrypted password from pi.ra-home.co.uk.yaml
    password: 'COPY_FROM_PI_CONFIG'
profile::postgresql::database_grants:
  foreman_db_access:
    privilege: ALL
    db: foreman
    role: foreman

# Foreman Server Configuration
profile::foreman::manage_foreman: true
profile::foreman::foreman_version: '3.7'  # Latest stable
profile::foreman::server_fqdn: 'foreman.ra-home.co.uk'  # UPDATED
profile::foreman::admin_username: 'admin'
# TODO: Copy encrypted password from pi.ra-home.co.uk.yaml
profile::foreman::admin_password: 'COPY_FROM_PI_CONFIG'
profile::foreman::db_host: 'localhost'
profile::foreman::db_database: 'foreman'
profile::foreman::db_username: 'foreman'
# TODO: Copy encrypted password from pi.ra-home.co.uk.yaml
profile::foreman::db_password: 'COPY_FROM_PI_CONFIG'
profile::foreman::enable_puppetserver: true
profile::foreman::enable_enc: true
profile::foreman::enable_reports: true
profile::foreman::initial_organization:
  name: 'RA Home'
  description: 'Home Infrastructure'
profile::foreman::initial_location:
  name: 'Home Network'
  description: 'Home network infrastructure'

# Foreman Smart Proxy Configuration
profile::foreman_proxy::manage_proxy: true
profile::foreman_proxy::foreman_base_url: 'https://foreman.ra-home.co.uk'  # UPDATED
profile::foreman_proxy::register_in_foreman: true
profile::foreman_proxy::manage_dns: true
profile::foreman_proxy::dns_provider: 'nsupdate'
profile::foreman_proxy::dns_server: '127.0.0.1'
profile::foreman_proxy::dns_ttl: 86400
profile::foreman_proxy::manage_dhcp: false
profile::foreman_proxy::manage_tftp: false
profile::foreman_proxy::manage_puppet: true
# TODO: Generate NEW OAuth credentials (don't copy from Pi)
profile::foreman_proxy::oauth_consumer_key: 'GENERATE_NEW'
profile::foreman_proxy::oauth_consumer_secret: 'GENERATE_NEW'

# Firewall Rules (accessible from VPN)
profile::firewall::custom_rules:
  foreman_https:
    port: 443
    proto: tcp
    source: '10.10.10.0/24'
    jump: accept
  foreman_http:
    port: 80
    proto: tcp
    source: '10.10.10.0/24'
    jump: accept
  puppetserver:
    port: 8140
    proto: tcp
    source: '10.10.10.0/24'
    jump: accept
  foreman_proxy:
    port: 8443
    proto: tcp
    source: '10.10.10.0/24'
    jump: accept
```

### 2. Update site.pp

Update `/home/ryan/repos/infra-puppet-control/manifests/site.pp`:

```puppet
# Add new Foreman node
node 'foreman.ra-home.co.uk' {
  include role::foreman
}

# Keep Pi node for gradual transition (remove after migration completes)
node 'pi.ra-home.co.uk' {
  include role::foreman
}
```

### 3. Generate New OAuth Credentials

```bash
# Generate new OAuth credentials for the new Foreman instance
uuidgen | eyaml encrypt -s  # consumer_key
uuidgen | eyaml encrypt -s  # consumer_secret
```

Update `data/nodes/foreman.ra-home.co.uk.yaml` with encrypted values.

---

## Migration Execution

### Phase 1: Deploy Base Configuration (No Downtime)

```bash
# 1. Commit Puppet changes
git add data/nodes/foreman.ra-home.co.uk.yaml manifests/site.pp
git commit -m "feat: add foreman.ra-home.co.uk node configuration for migration"
git push

# 2. SSH into new VPS
ssh foreman.ra-home.co.uk

# 3. Install Puppet agent
curl -O https://apt.puppetlabs.com/puppet7-release-el-9.noarch.rpm
sudo rpm -Uvh puppet7-release-el-9.noarch.rpm
sudo dnf install -y puppet-agent

# 4. Configure Puppet (bootstrap mode - no server yet)
# We'll use masterless mode initially
sudo mkdir -p /etc/puppetlabs/puppet/eyaml
sudo scp pi.ra-home.co.uk:/etc/puppetlabs/puppet/eyaml/*.pem /etc/puppetlabs/puppet/eyaml/

# 5. Clone control repo
cd /tmp
git clone <YOUR_CONTROL_REPO_URL> puppet-control
cd puppet-control

# 6. Install r10k and deploy modules
sudo /opt/puppetlabs/puppet/bin/gem install r10k
sudo /opt/puppetlabs/puppet/bin/r10k puppetfile install

# 7. Run Puppet (this will install PostgreSQL, Foreman, etc.)
sudo /opt/puppetlabs/bin/puppet apply \
  --environment production \
  --modulepath=/tmp/puppet-control/modules:/tmp/puppet-control/site-modules \
  --hiera_config=/tmp/puppet-control/hiera.yaml \
  /tmp/puppet-control/manifests/site.pp \
  --certname foreman.ra-home.co.uk
```

**Expected result:** Clean Foreman installation with empty database.

### Phase 2: PostgreSQL Data Migration (Downtime Starts)

```bash
# 1. Stop Foreman on Pi (downtime begins)
ssh pi.ra-home.co.uk
sudo systemctl stop foreman foreman-proxy

# 2. Create final database dump on Pi
sudo -u postgres pg_dump foreman > /tmp/foreman_final.sql
gzip /tmp/foreman_final.sql

# 3. Transfer dump to new VPS
scp /tmp/foreman_final.sql.gz foreman.ra-home.co.uk:/tmp/

# 4. On new VPS: Stop Foreman services
ssh foreman.ra-home.co.uk
sudo systemctl stop foreman foreman-proxy

# 5. Drop empty database and restore from backup
sudo -u postgres dropdb foreman
sudo -u postgres createdb -O foreman foreman
gunzip /tmp/foreman_final.sql.gz
sudo -u postgres psql foreman < /tmp/foreman_final.sql

# 6. Verify data restored
sudo -u postgres psql -d foreman -c "SELECT COUNT(*) FROM hosts;"
sudo -u postgres psql -d foreman -c "SELECT COUNT(*) FROM reports;"

# 7. Update Foreman configuration for new hostname
sudo -u postgres psql -d foreman <<EOF
UPDATE settings SET value='foreman.ra-home.co.uk' WHERE name='foreman_url';
UPDATE smart_proxies SET url=REPLACE(url, 'pi.ra-home.co.uk', 'foreman.ra-home.co.uk');
EOF

# 8. Rebuild OAuth consumer registration (new server = new OAuth)
# This will be handled automatically by Puppet on next run

# 9. Start services
sudo systemctl start foreman foreman-proxy

# 10. Verify Foreman web UI accessible
curl -k https://foreman.ra-home.co.uk
```

**Downtime duration:** ~15-30 minutes

### Phase 3: Verification

```bash
# 1. Connect via VPN (if not already connected)
# sudo wg-quick up wg0  # or however you connect to your VPN

# 2. Access Foreman web UI
# Browser: https://foreman.ra-home.co.uk
# Login with admin credentials from Hiera

# 3. Verify data migration
# - Check Hosts list (Infrastructure → Hosts)
# - Check Reports (Monitor → Reports)
# - Check Smart Proxies (Infrastructure → Smart Proxies)
# - Verify dashboard shows correct metrics

# 4. Test Puppet agent check-in (use vps.ra-home.co.uk or another managed node)
ssh vps.ra-home.co.uk

# If agent is configured to use pi.ra-home.co.uk, update to foreman.ra-home.co.uk
sudo puppet config set server foreman.ra-home.co.uk --section main
sudo puppet config set ca_server foreman.ra-home.co.uk --section main

# Run Puppet agent
sudo puppet agent -t

# 5. Verify report appears in Foreman
# Browser: Monitor → Reports (should see new report from VPS)
```

### Phase 4: Update Puppet Agents (Gradual)

**Option A: Update via Puppet code (recommended)**

Update your base profile to configure Puppet server:

```puppet
# site-modules/profile/manifests/base.pp
class profile::base (
  # ...
  String[1] $puppet_server = 'foreman.ra-home.co.uk',
  String[1] $puppet_ca_server = 'foreman.ra-home.co.uk',
) {
  # Configure Puppet agent
  ini_setting { 'puppet_server':
    ensure  => present,
    path    => "${puppet_conf_dir}/puppet.conf",
    section => 'main',
    setting => 'server',
    value   => $puppet_server,
  }

  ini_setting { 'puppet_ca_server':
    ensure  => present,
    path    => "${puppet_conf_dir}/puppet.conf",
    section => 'main',
    setting => 'ca_server',
    value   => $puppet_ca_server,
  }
}
```

Set in Hiera (`data/common.yaml`):
```yaml
profile::base::puppet_server: 'foreman.ra-home.co.uk'
profile::base::puppet_ca_server: 'foreman.ra-home.co.uk'
```

**Option B: Manual update per node**

```bash
# On each Puppet agent node
sudo puppet config set server foreman.ra-home.co.uk --section main
sudo puppet config set ca_server foreman.ra-home.co.uk --section main
sudo puppet agent -t
```

### Phase 5: Decommission Pi

**After 1-2 weeks of stable operation:**

```bash
# 1. Remove Pi node from site.pp
# (Delete or comment out the pi.ra-home.co.uk node definition)

# 2. Stop Foreman services on Pi
ssh pi.ra-home.co.uk
sudo systemctl stop foreman foreman-proxy postgresql
sudo systemctl disable foreman foreman-proxy postgresql

# 3. Archive final backups
sudo tar -czf /tmp/pi_foreman_archive_$(date +%Y%m%d).tar.gz \
  /etc/foreman \
  /etc/foreman-proxy \
  /var/lib/postgresql/13/data

# 4. Copy archive off Pi
scp pi.ra-home.co.uk:/tmp/pi_foreman_archive_*.tar.gz ~/foreman-backups/

# 5. Optional: Repurpose Pi
# - Use for local DNS/DHCP
# - Test environment
# - Lightweight monitoring
# - Or shut down to save power
```

---

## Rollback Plan

If migration fails, roll back to Pi:

```bash
# 1. Update DNS to point back to Pi
foreman.ra-home.co.uk  300  IN  A  <PI_IP_ADDRESS>

# 2. Start services on Pi
ssh pi.ra-home.co.uk
sudo systemctl start postgresql foreman foreman-proxy

# 3. Verify Pi Foreman operational
curl -k https://pi.ra-home.co.uk

# 4. Update Puppet agents back to Pi (if changed)
# (Use profile::base Hiera override or manual config change)

# 5. Investigate new VPS issues
# - Check logs: /var/log/foreman/
# - Check PostgreSQL: sudo -u postgres psql -d foreman
```

**Rollback duration:** ~5-10 minutes (DNS propagation may take longer)

---

## Post-Migration Optimizations

### 1. Performance Tuning

With 8GB RAM, you can optimize PostgreSQL:

```yaml
# data/nodes/foreman.ra-home.co.uk.yaml
profile::postgresql::shared_buffers: '2GB'        # 25% of RAM
profile::postgresql::effective_cache_size: '6GB'  # 75% of RAM
profile::postgresql::work_mem: '64MB'
profile::postgresql::maintenance_work_mem: '512MB'
profile::postgresql::max_connections: 200
```

### 2. Enable Puppet Server (if desired)

The VPS L has resources to run Puppet Server instead of just Foreman:

```yaml
# data/nodes/foreman.ra-home.co.uk.yaml
profile::puppetserver::manage_puppetserver: true
profile::puppetserver::java_xms: '1g'
profile::puppetserver::java_xmx: '2g'
profile::puppetserver::jruby_instances: 3
```

### 3. Monitoring

Add node exporter to Foreman server:

```yaml
# data/nodes/foreman.ra-home.co.uk.yaml
profile::base::install_node_exporter: true
```

Then update VictoriaMetrics scrape config to include new Foreman server.

---

## Timeline Summary

| Phase | Duration | Downtime | Description |
|-------|----------|----------|-------------|
| Pre-migration prep | 1-2 hours | None | Backups, DNS, Puppet config |
| Base deployment | 30-45 min | None | Install Foreman on new VPS |
| Database migration | 15-30 min | **YES** | Stop Pi, migrate data, start new VPS |
| Verification | 30-60 min | None | Test all functionality |
| Agent updates | Gradual | None | Update agents over days/weeks |
| Pi decommission | 1-2 weeks later | None | Archive and repurpose |

**Total estimated time:** 2-3 hours active work + 1-2 weeks gradual transition

---

## Success Criteria

- [ ] Foreman web UI accessible at https://foreman.ra-home.co.uk
- [ ] All hosts visible in Foreman dashboard
- [ ] Historical reports preserved
- [ ] Smart Proxy registered and functional
- [ ] Puppet agents successfully check in and receive catalogs
- [ ] No database errors in `/var/log/foreman/production.log`
- [ ] No proxy errors in `/var/log/foreman-proxy/proxy.log`
- [ ] DNS integration working (if used)
- [ ] Performance improved (page loads, catalog compilation)
- [ ] Pi services stopped and archived

---

## Contacts & Resources

- **Foreman Logs:** `/var/log/foreman/production.log`
- **Proxy Logs:** `/var/log/foreman-proxy/proxy.log`
- **PostgreSQL Logs:** `/var/log/postgresql/`
- **Foreman Docs:** https://theforeman.org/manuals/latest/
- **Database Backup Location:** `~/foreman-backups/`

---

## Notes

- Keep Pi powered on for at least 1-2 weeks after migration in case rollback needed
- DNS TTL set to 300s (5 min) allows quick rollback
- All encrypted passwords copied from existing configuration
- New OAuth credentials generated for security best practices
- VPS L resources allow future expansion (Puppet Server, additional services)
