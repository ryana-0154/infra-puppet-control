# Cloud-Init Configuration for Puppet Bootstrapping

This directory contains cloud-init configurations to quickly provision new hosts with Puppet agent.

## Quick Start

1. **Choose a template** based on your needs:
   - `base.yaml` - Basic host with Puppet agent
   - `vps.yaml` - VPS with WireGuard client pre-configured
   - `foreman-client.yaml` - Host that registers with Foreman ENC

2. **Customize the template**:
   - Replace `YOUR_SSH_PUBLIC_KEY_HERE` with your SSH public key
   - Update the hostname
   - Adjust any role-specific settings

3. **Use with your cloud provider**:

   **DigitalOcean / Linode / Vultr:**
   ```bash
   # Pass the cloud-init file during droplet/instance creation
   doctl compute droplet create my-host \
     --image rocky-9-x64 \
     --size s-1vcpu-1gb \
     --region nyc3 \
     --user-data-file cloud-init/base.yaml
   ```

   **AWS EC2:**
   ```bash
   aws ec2 run-instances \
     --image-id ami-xxxxxx \
     --instance-type t3.micro \
     --user-data file://cloud-init/base.yaml
   ```

   **ProxmoxVE:**
   ```bash
   # Add cloud-init drive to VM template
   qm set 9000 --cicustom "user=local:snippets/puppet-base.yaml"
   ```

   **IONOS:**
   ```bash
   ionosctl server create \
     --datacenter-id <DATACENTER_ID> \
     --name myhost.ra-home.co.uk \
     --cores 2 --ram 2048 \
     --image-alias rocky:9 \
     --user-data-file cloud-init/base.yaml \
     --wait
   ```
   *For detailed IONOS setup including DCD GUI method, see [IONOS.md](IONOS.md)*

   **Manual (existing server):**
   ```bash
   # Copy cloud-init config to server
   scp cloud-init/base.yaml root@newhost:/tmp/cloud-init.yaml

   # Run cloud-init manually
   ssh root@newhost
   cloud-init clean
   cloud-init init --file /tmp/cloud-init.yaml
   cloud-init modules --mode config
   cloud-init modules --mode final
   ```

## Template Files

### base.yaml
Basic configuration suitable for most hosts:
- Installs Puppet 7 agent (Rocky Linux / Debian)
- Configures Puppet server (Foreman at pi.ra-home.co.uk)
- Sets up SSH hardening
- Runs initial Puppet agent
- Configures automatic security updates

**Use for:** General purpose servers, workstations, development boxes

### vps.yaml
VPS-specific configuration with WireGuard client:
- Everything from base.yaml
- Pre-configures WireGuard client
- Sets up firewall (UFW)
- Configures WireGuard to auto-connect to VPN server

**Use for:** Public-facing VPS instances that need VPN access

### foreman-client.yaml
Foreman ENC (External Node Classifier) client:
- Everything from base.yaml
- Configures Puppet agent to report to Foreman
- Sets up Foreman facts upload
- Enables Foreman integration features

**Use for:** Hosts managed by Foreman (pi.ra-home.co.uk)

## Configuration Variables

All templates support these customizations:

```yaml
#cloud-config
hostname: YOUR_HOSTNAME  # Change this
fqdn: YOUR_HOSTNAME.ra-home.co.uk  # Change this

users:
  - name: YOUR_USERNAME  # Change this
    ssh_authorized_keys:
      - YOUR_SSH_PUBLIC_KEY_HERE  # Change this

# Puppet server configuration
write_files:
  - path: /etc/puppetlabs/puppet/puppet.conf
    content: |
      [main]
      server = pi.ra-home.co.uk  # Change if using different Puppet server
      certname = YOUR_HOSTNAME.ra-home.co.uk
      environment = production
```

## Advanced Usage

### Custom Hiera Data

Add node-specific Hiera data during provisioning:

```yaml
write_files:
  - path: /tmp/node-hiera.yaml
    content: |
      ---
      profile::base::custom_setting: "value"

runcmd:
  - scp /tmp/node-hiera.yaml puppet-server:/etc/puppetlabs/code/environments/production/data/nodes/$(hostname -f).yaml
```

### WireGuard Client Setup

The VPS template includes WireGuard client configuration. To use it:

1. **Generate client keys** on your local machine:
   ```bash
   wg genkey | tee client.key | wg pubkey > client.pub
   wg genpsk > client.psk
   ```

2. **Add peer to server** - Update `data/nodes/vps.ra-home.co.uk.yaml`:
   ```yaml
   profile::wireguard::peers:
     newhost:
       public_key: '<public key from client.pub>'
       preshared_key: '<preshared key from client.psk>'
       allowed_ips: '10.10.10.X/32'  # Choose next available IP
   ```

3. **Update cloud-init template** - Replace WireGuard configuration in `vps.yaml`:
   ```yaml
   - path: /etc/wireguard/wg0.conf
     content: |
       [Interface]
       PrivateKey = <private key from client.key>
       Address = 10.10.10.X/24
       DNS = 10.10.10.1

       [Peer]
       PublicKey = <server public key>
       PresharedKey = <preshared key from client.psk>
       Endpoint = <VPS_PUBLIC_IP>:51820
       AllowedIPs = 10.10.10.0/24
       PersistentKeepalive = 25
   ```

4. **Deploy and verify**:
   ```bash
   # On new host after cloud-init completes
   sudo wg-quick up wg0
   sudo wg show
   ping 10.10.10.1
   ```

### Puppet Certificate Signing

**Option 1: Auto-sign (development only)**
```bash
# On Puppet server
echo "*.ra-home.co.uk" >> /etc/puppetlabs/puppet/autosign.conf
```

**Option 2: Manual signing (production)**
```bash
# On new host - request certificate
sudo puppet agent -t

# On Puppet server - list and sign
sudo puppetserver ca list
sudo puppetserver ca sign --certname newhost.ra-home.co.uk
```

**Option 3: Foreman auto-signing**
Foreman can auto-sign certificates if configured in Settings → Puppet → Auto-sign entries

## Testing

Before deploying to production, test your cloud-init configuration:

```bash
# Validate YAML syntax
yamllint cloud-init/base.yaml

# Test with cloud-init schema validator
cloud-init schema --config-file cloud-init/base.yaml

# Dry run (requires cloud-init installed)
cloud-init devel schema -c cloud-init/base.yaml
```

## Troubleshooting

**Cloud-init didn't run:**
```bash
# Check cloud-init status
cloud-init status --long

# View logs
cat /var/log/cloud-init.log
cat /var/log/cloud-init-output.log
```

**Puppet agent failed:**
```bash
# Check Puppet agent status
systemctl status puppet

# Run Puppet manually with debug
puppet agent -t --debug

# Check certificate status
puppet agent --fingerprint
```

**WireGuard not connecting:**
```bash
# Check WireGuard status
wg show
systemctl status wg-quick@wg0

# Check firewall
ufw status
```

## Security Notes

1. **SSH Keys**: Always use SSH key authentication, disable password auth
2. **Secrets**: Never put unencrypted secrets in cloud-init files
   - Use Puppet/Hiera with eyaml for secrets
   - Or use cloud provider secret management (AWS Secrets Manager, etc.)
3. **Auto-signing**: Only use Puppet certificate auto-signing in development
4. **Updates**: All templates enable automatic security updates via unattended-upgrades

## Examples

### Provision a new VPS at DigitalOcean

```bash
# 1. Customize the template
cp cloud-init/vps.yaml /tmp/my-vps.yaml
sed -i 's/YOUR_HOSTNAME/web01/g' /tmp/my-vps.yaml
sed -i "s|YOUR_SSH_PUBLIC_KEY_HERE|$(cat ~/.ssh/id_rsa.pub)|g" /tmp/my-vps.yaml

# 2. Create the droplet
doctl compute droplet create web01.ra-home.co.uk \
  --image rockylinux-9-x64 \
  --size s-2vcpu-2gb \
  --region nyc3 \
  --user-data-file /tmp/my-vps.yaml \
  --wait

# 3. Get the IP and test SSH
doctl compute droplet list
ssh ryan@<IP_ADDRESS>

# 4. Sign Puppet certificate (on Puppet server)
sudo puppetserver ca sign --certname web01.ra-home.co.uk

# 5. Run Puppet (on new host)
sudo puppet agent -t
```

### Provision ProxmoxVE VM

```bash
# 1. Upload cloud-init to Proxmox
scp cloud-init/base.yaml root@proxmox:/var/lib/vz/snippets/puppet-base.yaml

# 2. Create VM from template with cloud-init
qm clone 9000 200 --name testvm
qm set 200 --cicustom "user=local:snippets/puppet-base.yaml"
qm set 200 --ipconfig0 ip=192.168.1.50/24,gw=192.168.1.1
qm start 200

# 3. Wait for cloud-init to complete and test
ssh ryan@192.168.1.50
```

## See Also

- [Cloud-init documentation](https://cloudinit.readthedocs.io/)
- [Puppet agent installation](https://puppet.com/docs/puppet/latest/install_agents.html)
- [Foreman provisioning](https://theforeman.org/manuals/latest/index.html#4.4Provisioning)
