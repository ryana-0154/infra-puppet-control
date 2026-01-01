# Cloud-Init Quick Start for Rocky Linux 9

## Fastest Path to a New Host

### 1. Use the Helper Script (Recommended)

```bash
cd cloud-init
chmod +x customize.sh
./customize.sh
```

The script will:
- Ask for hostname
- Select your SSH key
- Generate WireGuard keys (for VPS template)
- Create customized cloud-init in `generated/` directory
- Provide Puppet peer configuration

### 2. Deploy to Cloud Provider

**DigitalOcean:**
```bash
doctl compute droplet create myhost.ra-home.co.uk \
  --image rockylinux-9-x64 \
  --size s-1vcpu-1gb \
  --region nyc3 \
  --user-data-file cloud-init/generated/myhost.yaml
```

**Linode:**
```bash
linode-cli linodes create \
  --label myhost \
  --image linode/rocky9 \
  --type g6-nanode-1 \
  --region us-east \
  --metadata.user_data "$(base64 -w0 cloud-init/generated/myhost.yaml)"
```

**Vultr:**
```bash
vultr-cli instance create \
  --region ewr \
  --plan vc2-1c-1gb \
  --os 542 \  # Rocky Linux 9
  --userdata="$(cat cloud-init/generated/myhost.yaml)"
```

**IONOS:**
```bash
ionosctl server create \
  --datacenter-id <DATACENTER_ID> \
  --name myhost.ra-home.co.uk \
  --cores 2 \
  --ram 2048 \
  --image-alias rocky:9 \
  --user-data-file cloud-init/generated/myhost.yaml \
  --wait
```
*See [IONOS.md](IONOS.md) for detailed IONOS setup*

### 3. Complete Setup

#### For VPS with WireGuard:

**On Puppet Server (pi.ra-home.co.uk):**
```bash
# 1. Add peer configuration to Hiera
vim data/nodes/vps.ra-home.co.uk.yaml
# (Copy from generated/myhost-peer-config.yaml)

# 2. Commit and deploy
git add data/nodes/vps.ra-home.co.uk.yaml
git commit -m "Add WireGuard peer for myhost"
git push

# 3. Apply Puppet on VPS server
ssh vps.ra-home.co.uk
sudo puppet agent -t

# 4. Sign new host certificate
sudo puppetserver ca list
sudo puppetserver ca sign --certname myhost.ra-home.co.uk
```

**On New Host:**
```bash
# Wait for cloud-init to complete (check status)
cloud-init status --wait

# Verify WireGuard
sudo wg show
ping 10.10.10.1

# Run Puppet
sudo puppet agent -t
```

#### For Base Host:

**On Puppet Server:**
```bash
# Sign certificate
sudo puppetserver ca sign --certname myhost.ra-home.co.uk
```

**On New Host:**
```bash
# Run Puppet
sudo puppet agent -t
```

## Manual Customization (No Helper Script)

If you prefer manual customization:

```bash
# 1. Copy template
cp cloud-init/base.yaml /tmp/myhost.yaml

# 2. Replace placeholders
sed -i 's/YOUR_HOSTNAME/myhost/g' /tmp/myhost.yaml
sed -i "s|YOUR_SSH_PUBLIC_KEY_HERE|$(cat ~/.ssh/id_rsa.pub)|g" /tmp/myhost.yaml

# 3. For VPS template - generate WireGuard keys
wg genkey | tee client.key | wg pubkey > client.pub
wg genpsk > client.psk

# 4. Update WireGuard placeholders manually
vim /tmp/myhost.yaml
```

## Troubleshooting

### Check cloud-init progress:
```bash
# Monitor log in real-time
tail -f /var/log/cloud-init-output.log

# Check status
cloud-init status --long

# View final result
cat /var/log/cloud-init.log
```

### Common Issues:

**Puppet certificate not signing:**
- Check hostname matches: `hostname -f`
- Verify Puppet server connection: `telnet pi.ra-home.co.uk 8140`
- Check Puppet logs: `journalctl -u puppet -f`

**WireGuard not connecting:**
- Verify server peer is configured in Puppet
- Check firewall: `sudo ufw status`
- Test connectivity: `ping -c 3 <VPS_PUBLIC_IP>`
- Check WireGuard logs: `journalctl -u wg-quick@wg0 -f`

**Cloud-init didn't run:**
- Some cloud providers need cloud-init installed in the image
- For Rocky Linux 9, cloud-init should be pre-installed
- Verify: `rpm -q cloud-init`

## Next Steps After Provisioning

1. **Verify Puppet is managing the host:**
   ```bash
   sudo puppet agent -t --debug
   sudo facter -p
   ```

2. **Check role assignment:**
   ```bash
   # View the assigned role
   grep 'role::' /etc/puppetlabs/code/environments/production/manifests/site.pp
   ```

3. **Create node-specific Hiera data** (if needed):
   ```bash
   # On Puppet server
   vim data/nodes/myhost.ra-home.co.uk.yaml
   ```

4. **Test connectivity** (for VPS):
   ```bash
   # From VPN
   ping 10.10.10.X
   ssh ryan@10.10.10.X

   # Access Pi-hole
   curl http://10.10.10.1/admin
   ```

## Templates Overview

| Template | Use Case | Includes |
|----------|----------|----------|
| `base.yaml` | General hosts | Puppet agent, SSH hardening, fail2ban |
| `vps.yaml` | Public VPS | Base + WireGuard client, UFW firewall |
| `foreman-client.yaml` | Foreman-managed | Base + Foreman ENC integration |

## Examples

### Provision Development Server
```bash
./customize.sh
# Select: base
# Hostname: dev01
# SSH: Use default key

doctl compute droplet create dev01.ra-home.co.uk \
  --image rockylinux-9-x64 \
  --size s-2vcpu-2gb \
  --region nyc3 \
  --user-data-file generated/dev01.yaml
```

### Provision VPS with Full VPN
```bash
./customize.sh
# Select: vps
# Hostname: web02
# SSH: Use default key
# WireGuard: Yes, generate keys
# VPN IP: 10.10.10.20
# Server IP: <your-vps-public-ip>

# Update Puppet with peer config (shown by script)
# Then deploy:
doctl compute droplet create web02.ra-home.co.uk \
  --image rockylinux-9-x64 \
  --size s-1vcpu-1gb \
  --region nyc3 \
  --user-data-file generated/web02.yaml
```

## Security Notes

- All templates disable SSH password authentication
- Puppet certificates require manual signing (production security)
- WireGuard keys are unique per host
- Fail2ban is automatically configured
- Automatic security updates enabled via unattended-upgrades

## See Also

- [Full README](README.md) - Comprehensive documentation
- [Cloud-init docs](https://cloudinit.readthedocs.io/)
- [Puppet agent install](https://puppet.com/docs/puppet/latest/install_agents.html)
