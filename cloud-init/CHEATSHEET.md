# Cloud-Init Cheat Sheet

## One-Liners

### Generate Config (Interactive)
```bash
cd cloud-init && ./customize.sh
```

### Deploy to DigitalOcean
```bash
doctl compute droplet create myhost.ra-home.co.uk \
  --image rockylinux-9-x64 --size s-1vcpu-1gb --region nyc3 \
  --user-data-file cloud-init/generated/myhost.yaml
```

### Deploy to Linode
```bash
linode-cli linodes create --label myhost --image linode/rocky9 \
  --type g6-nanode-1 --region us-east \
  --metadata.user_data "$(base64 -w0 cloud-init/generated/myhost.yaml)"
```

### Deploy to IONOS
```bash
ionosctl server create --datacenter-id <DC_ID> --name myhost.ra-home.co.uk \
  --cores 2 --ram 2048 --image-alias rocky:9 \
  --user-data-file cloud-init/generated/myhost.yaml --wait
```

### Sign Puppet Certificate
```bash
ssh pi.ra-home.co.uk sudo puppetserver ca sign --certname myhost.ra-home.co.uk
```

### Check Cloud-Init Status
```bash
ssh myhost cloud-init status --long
```

### Run Puppet
```bash
ssh myhost sudo puppet agent -t
```

## Quick Customization (Manual)

```bash
# Copy template
cp cloud-init/base.yaml /tmp/myhost.yaml

# Replace hostname
sed -i 's/YOUR_HOSTNAME/myhost/g' /tmp/myhost.yaml

# Add SSH key
sed -i "s|YOUR_SSH_PUBLIC_KEY_HERE|$(cat ~/.ssh/id_rsa.pub)|g" /tmp/myhost.yaml
```

## WireGuard Key Generation

```bash
# Generate client keys
wg genkey | tee client.key | wg pubkey > client.pub
wg genpsk > client.psk

# Show keys
echo "Private: $(cat client.key)"
echo "Public:  $(cat client.pub)"
echo "PSK:     $(cat client.psk)"

# Encrypt PSK for Puppet
eyaml encrypt -s "$(cat client.psk)"
```

## Common Puppet Tasks

### Add Node Classification
```bash
cat >> manifests/site.pp <<EOF

node 'myhost.ra-home.co.uk' {
  include role::base
}
EOF
```

### Create Hiera Data
```bash
cat > data/nodes/myhost.ra-home.co.uk.yaml <<EOF
---
profile::base::manage_firewall: true
EOF
```

### Commit Changes
```bash
git add manifests/site.pp data/nodes/myhost.ra-home.co.uk.yaml
git commit -m "Add myhost configuration"
git push
```

## Troubleshooting Commands

```bash
# Cloud-init logs
ssh HOST tail -f /var/log/cloud-init-output.log
ssh HOST cat /var/log/cloud-init.log | grep -i error

# Puppet debug
ssh HOST sudo puppet agent -t --debug

# Certificate check
ssh HOST sudo puppet agent --fingerprint
ssh pi.ra-home.co.uk sudo puppetserver ca list

# WireGuard status
ssh HOST sudo wg show
ssh HOST systemctl status wg-quick@wg0
ssh HOST ping 10.10.10.1

# Service status
ssh HOST systemctl status puppet
ssh HOST systemctl status fail2ban
ssh HOST sudo ufw status
```

## File Paths Reference

```
On New Host:
/var/log/cloud-init.log              - Cloud-init execution log
/var/log/cloud-init-output.log       - Command output log
/etc/puppetlabs/puppet/puppet.conf   - Puppet agent config
/etc/wireguard/wg0.conf              - WireGuard config (VPS)
/etc/fail2ban/jail.local             - Fail2ban config

On Puppet Server (pi.ra-home.co.uk):
/etc/puppetlabs/code/environments/production/manifests/site.pp
/etc/puppetlabs/code/environments/production/data/nodes/HOST.yaml
```

## Validation

```bash
# Validate YAML
python3 -c "import yaml; yaml.safe_load(open('generated/HOST.yaml'))"

# Test with cloud-init (if installed)
cloud-init schema --config-file generated/HOST.yaml

# Test in local VM
multipass launch rocky --name test --cloud-init generated/HOST.yaml
multipass exec test -- cloud-init status --long
```

## Common VPS Sizes

| Provider | Smallest | Recommended | Large |
|----------|----------|-------------|-------|
| DigitalOcean | s-1vcpu-1gb | s-2vcpu-2gb | s-4vcpu-8gb |
| Linode | g6-nanode-1 | g6-standard-2 | g6-standard-4 |
| Vultr | vc2-1c-1gb | vc2-2c-4gb | vc2-4c-8gb |

## Security Checklist

- [ ] SSH key added (no password auth)
- [ ] Unique WireGuard keys generated
- [ ] Puppet certificate manually signed (no auto-sign)
- [ ] Firewall enabled (UFW/iptables)
- [ ] Fail2ban configured
- [ ] Automatic updates enabled
- [ ] Secrets encrypted with eyaml (Puppet)
- [ ] Generated configs not committed to git

## Quick Recovery

```bash
# Rebuild failed host
doctl compute droplet delete myhost.ra-home.co.uk
ssh pi.ra-home.co.uk sudo puppetserver ca clean --certname myhost.ra-home.co.uk
doctl compute droplet create myhost.ra-home.co.uk \
  --image rockylinux-9-x64 --size s-1vcpu-1gb --region nyc3 \
  --user-data-file cloud-init/generated/myhost.yaml
# Wait 3 minutes, then sign cert and run puppet
```

## Template Selection

- **base.yaml** → General hosts, dev boxes, internal services
- **vps.yaml** → Public VPS, internet-facing, needs VPN
- **foreman-client.yaml** → Foreman-managed infrastructure

## Post-Deployment Checklist

- [ ] Cloud-init completed: `cloud-init status`
- [ ] Puppet connected: `puppet agent -t`
- [ ] Certificate signed: `puppetserver ca list`
- [ ] Services running: `systemctl status puppet`
- [ ] VPN connected (if VPS): `wg show` + `ping 10.10.10.1`
- [ ] Firewall active: `ufw status` or `iptables -L`
- [ ] SSH key works: No password prompt
- [ ] Fail2ban active: `fail2ban-client status`

## Emergency Access

If SSH key auth fails:
```bash
# Use cloud provider console/VNC
# Check authorized_keys
cat ~/.ssh/authorized_keys

# Check SSH config
sudo grep -i pubkeyauth /etc/ssh/sshd_config

# Restart SSH
sudo systemctl restart sshd
```

## Cleanup Commands

```bash
# Remove generated configs (contains keys!)
rm -rf cloud-init/generated/*

# Clean up failed deployments
doctl compute droplet list | grep myhost
doctl compute droplet delete myhost.ra-home.co.uk

# Remove Puppet certificate
ssh pi.ra-home.co.uk sudo puppetserver ca clean --certname myhost.ra-home.co.uk
```
