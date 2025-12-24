# PiHole Automatic Provisioning

This guide explains how to automatically provision PiHole with your settings using Puppet, based on a PiHole Teleporter backup.

## Overview

The `profile::pihole` module automates PiHole configuration by:
1. Deploying your pihole.toml configuration
2. Restoring blocklists/whitelists from gravity.db
3. Applying custom DNS hosts
4. Restarting PiHole when configuration changes

## Prerequisites

- PiHole running in a Docker container
- A pihole-teleporter.zip backup from your existing PiHole
- eyaml configured for secret encryption

## Initial Setup

### 1. Extract Your Password Hash

Your PiHole password hash is required for API authentication. Extract it from your backup:

```bash
# Extract and find the password hash
unzip -p pihole-teleporter.zip etc/pihole/pihole.toml | grep "pwhash ="
```

You'll see something like:
```
pwhash = "$BALLOON-SHA256$v=1$s=1024,t=32$XS5cygjTX9ZDKxRzyxE+kg==$PwLIu3J8TfKTeDP8p2KjEIgBqca+UqH6BCpKhofuq9U="
```

### 2. Encrypt the Password Hash

**IMPORTANT**: Never commit the password hash in plaintext!

```bash
# Encrypt with eyaml
eyaml encrypt -s '$BALLOON-SHA256$v=1$s=1024,t=32$XS5cygjTX9ZDKxRzyxE+kg==$PwLIu3J8TfKTeDP8p2KjEIgBqca+UqH6BCpKhofuq9U='
```

### 3. Configure Hiera

Add to your node-specific Hiera file (e.g., `data/nodes/yournode.yaml`):

```yaml
# Enable PiHole provisioning
profile::pihole::manage_pihole: true

# Encrypted password hash
profile::pihole::pihole_password_hash: >
  ENC[PKCS7,MIIBeQYJKoZIhvcNAQcDoIIBajCCAWYCAQAxggEhMIIBHQIBADAFMAACAQEw...]
```

### 4. Apply Configuration

```bash
puppet agent -t
```

PiHole will restart with your configuration applied.

## What Gets Provisioned

### pihole.toml (Configuration File)

The complete PiHole configuration including:
- **DNS Settings**: Upstream servers, DNSSEC, conditional forwarding
- **Blocking Behavior**: ESNI blocking, CNAME inspection, blocking modes
- **Web Interface**: API settings, theme, authentication
- **DHCP**: DHCP server configuration (if enabled)
- **Database**: Query logging, privacy settings
- **Performance**: Cache settings, rate limiting

### gravity.db (Blocklists Database)

- Adlist subscriptions (blocklist URLs)
- Whitelisted domains
- Blacklisted domains
- Regex filters
- Group configurations
- Domain-to-group assignments

### custom.list (Custom DNS Hosts)

- Custom DNS records
- Local hostname mappings
- Equivalent to /etc/hosts entries

## Configuration Options

All options with their defaults:

```yaml
# Whether to manage PiHole configuration (disabled by default)
profile::pihole::manage_pihole: false

# PiHole configuration directory
profile::pihole::pihole_config_dir: '/etc/pihole'

# Docker container name
profile::pihole::pihole_container_name: 'pihole'

# Provision blocklists/whitelists database
profile::pihole::provision_gravity_db: true

# Provision custom hosts file
profile::pihole::provision_custom_hosts: true

# Restart PiHole when config changes
profile::pihole::restart_on_config_change: true

# File ownership for gravity.db (use 'root' for Docker bind mounts)
profile::pihole::gravity_db_owner: 'root'
profile::pihole::gravity_db_group: 'root'

# Password hash (REQUIRED - must be encrypted with eyaml)
profile::pihole::pihole_password_hash: >
  ENC[PKCS7,...]
```

### Docker Requirements

This profile assumes:
- Docker is installed and running
- The PiHole container exists (will be created if using docker-compose or another method)
- Files are bind-mounted from `/etc/pihole` on the host into the container

The profile will verify the container exists before attempting to restart it.

## Updating Configuration

### Method 1: Manual Update

1. Make changes in PiHole web interface
2. Export backup: Settings → Teleporter → Backup
3. Download `pihole-teleporter.zip` to repo root
4. Extract and update module files:
   ```bash
   ./scripts/update-pihole-from-backup.sh
   ```
5. Commit changes:
   ```bash
   git add site-modules/profile/files/pihole/
   git add site-modules/profile/templates/pihole/
   git commit -m "Update PiHole configuration"
   ```
6. Apply: `puppet agent -t`

### Method 2: Direct File Updates

If you only need to update specific settings:

1. Edit `site-modules/profile/templates/pihole/pihole.toml.erb` directly
2. Update blocklists: Replace `site-modules/profile/files/pihole/gravity.db`
3. Update hosts: Edit `site-modules/profile/files/pihole/custom_hosts`
4. Commit and apply

## Rolling Back Configuration

If a configuration change breaks PiHole, you have several rollback options:

### Option 1: Quick Disable (Emergency)

Temporarily disable Puppet provisioning to restore PiHole manually:

```bash
# In Hiera configuration
echo "profile::pihole::manage_pihole: false" >> data/nodes/yournode.yaml
puppet agent -t

# Manually fix PiHole
docker exec -it pihole bash
# Edit /etc/pihole/pihole.toml or restore from backup
# Exit container

# Re-enable provisioning after fixing the issue
```

### Option 2: Git Revert to Previous Configuration

```bash
# Find the commit with working configuration
git log --oneline site-modules/profile/

# Revert to specific commit
git checkout <commit-hash> site-modules/profile/files/pihole/
git checkout <commit-hash> site-modules/profile/templates/pihole/

# Apply the old configuration
git add site-modules/profile/
git commit -m "Rollback PiHole configuration to working state"
puppet agent -t
```

### Option 3: Restore from PiHole Teleporter Backup

If you have a working `pihole-teleporter.zip` backup:

```bash
# Copy the backup to the repo root
cp /path/to/working/pihole-teleporter.zip .

# Extract and update module files
./scripts/update-pihole-from-backup.sh

# Commit and apply
git add site-modules/profile/
git commit -m "Restore PiHole configuration from backup"
puppet agent -t
```

### Option 4: Disable Auto-Restart for Testing

Before applying risky changes, disable auto-restart to test manually:

```yaml
profile::pihole::restart_on_config_change: false
```

Apply configuration, then manually restart when ready:

```bash
docker restart pihole
# Check logs
docker logs pihole
```

## Selective Provisioning

### Provision Only Configuration (No Blocklists)

```yaml
profile::pihole::provision_gravity_db: false
profile::pihole::provision_custom_hosts: false
```

This only deploys pihole.toml settings.

### Provision Only Blocklists

```yaml
profile::pihole::provision_gravity_db: true
profile::pihole::provision_custom_hosts: false
```

Useful for updating blocklists without changing DNS settings.

## Troubleshooting

### PiHole Won't Start After Provisioning

**Check logs:**
```bash
docker logs pihole
```

**Common issues:**
- Malformed pihole.toml (TOML syntax error)
- Invalid upstream DNS server
- Port conflicts (if DHCP enabled)

**Solution:**
```bash
# Temporarily disable provisioning
echo "profile::pihole::manage_pihole: false" >> data/nodes/yournode.yaml
puppet agent -t

# Fix PiHole manually
docker exec -it pihole bash
vi /etc/pihole/pihole.toml

# Re-enable provisioning
```

### Password Authentication Fails

**Verify hash format:**
```bash
# Check that hash starts with $BALLOON-SHA256$
grep pwhash /etc/pihole/pihole.toml
```

**Generate new hash:**
```bash
# Inside PiHole container
pihole -a -p newpassword

# Extract new hash
grep pwhash /etc/pihole/pihole.toml
```

### Blocklists Not Updating

**Force gravity update:**
```bash
docker exec pihole pihole -g
```

**Check database:**
```bash
# Verify gravity.db was deployed
docker exec pihole ls -lh /etc/pihole/gravity.db

# Check adlist count
docker exec pihole sqlite3 /etc/pihole/gravity.db "SELECT COUNT(*) FROM adlist;"
```

### Configuration Changes Not Applied

**Check Puppet run:**
```bash
puppet agent -t --debug | grep pihole
```

**Verify file deployed:**
```bash
docker exec pihole cat /etc/pihole/pihole.toml | grep upstreams
```

**Force restart:**
```bash
docker restart pihole
```

## Security Best Practices

1. **Never commit pihole-teleporter.zip**
   - Contains password hash and potentially query history
   - Already in .gitignore

2. **Always encrypt password hash**
   - Use eyaml for all Hiera values
   - Never commit plaintext hashes

3. **Limit access to gravity.db**
   - May contain whitelisted domains that reveal browsing patterns
   - Review before committing

4. **Review custom hosts**
   - May contain internal network information
   - Sanitize if repo is public

5. **Backup PiHole regularly**
   - Export teleporter backup weekly
   - Store securely (encrypted)

## Advanced Usage

### Multiple PiHole Instances

Deploy different configurations to different nodes:

```yaml
# Primary PiHole
nodes/pihole-primary.yaml:
  profile::pihole::pihole_container_name: 'pihole'
  profile::pihole::pihole_password_hash: >
    ENC[PKCS7,...]

# Secondary PiHole (different config)
nodes/pihole-secondary.yaml:
  profile::pihole::pihole_container_name: 'pihole'
  profile::pihole::pihole_password_hash: >
    ENC[PKCS7,different_hash...]
```

### Testing Changes

```yaml
# Disable auto-restart for testing
profile::pihole::restart_on_config_change: false
```

Apply configuration, then manually restart when ready:
```bash
docker restart pihole
```

### Conditional Provisioning

```yaml
# Only provision on specific OS
profile::pihole::manage_pihole: "%{lookup('os.family') == 'Debian'}"
```

## Integration with Monitoring

If using the monitoring profile, connect PiHole exporter:

```yaml
profile::monitoring::enable_pihole_exporter: true
profile::monitoring::pihole_hostname: 'localhost'
profile::monitoring::pihole_port: 80
profile::monitoring::pihole_api_token: >
  ENC[PKCS7,...]  # From pihole.toml
```

## Files Structure

```
site-modules/profile/
├── manifests/
│   └── pihole.pp                    # Main profile
├── templates/
│   └── pihole/
│       └── pihole.toml.erb          # Configuration template (1680 lines)
├── files/
│   └── pihole/
│       ├── gravity.db               # Blocklists database (32KB)
│       └── custom_hosts             # Custom DNS hosts
└── spec/
    └── classes/
        └── pihole_spec.rb           # Tests
```

## References

- [Pi-hole Documentation](https://docs.pi-hole.net/)
- [Pi-hole Teleporter](https://docs.pi-hole.net/core/pihole-command/#teleporter)
- [Pi-hole FTL Configuration](https://docs.pi-hole.net/ftldns/configfile/)
