# Cloud-Init Usage Examples

## Example 1: New Web Server

**Scenario:** Deploy a new web server to host a React application

```bash
# 1. Generate cloud-init config
cd /home/ryan/repos/infra-puppet-control/cloud-init
./customize.sh
# Choose: (1) base
# Hostname: web03
# SSH Key: (1) Use default

# 2. Add node classification to Puppet
cat >> /home/ryan/repos/infra-puppet-control/manifests/site.pp <<'EOF'

node 'web03.ra-home.co.uk' {
  include role::webserver
}
EOF

# 3. Create node-specific Hiera
cat > /home/ryan/repos/infra-puppet-control/data/nodes/web03.ra-home.co.uk.yaml <<'EOF'
---
# Web server configuration
profile::base::manage_firewall: true

# Open HTTP/HTTPS
profile::firewall::custom_rules:
  http:
    port: 80
    proto: tcp
    jump: accept
  https:
    port: 443
    proto: tcp
    jump: accept
EOF

# 4. Commit Puppet changes
git add manifests/site.pp data/nodes/web03.ra-home.co.uk.yaml
git commit -m "Add web03 host configuration"
git push

# 5. Deploy to DigitalOcean
doctl compute droplet create web03.ra-home.co.uk \
  --image rockylinux-9-x64 \
  --size s-2vcpu-2gb \
  --region nyc3 \
  --user-data-file generated/web03.yaml \
  --wait

# 6. Get IP and wait for cloud-init
IP=$(doctl compute droplet list --format Name,PublicIPv4 | grep web03 | awk '{print $2}')
echo "Server IP: $IP"

# Wait ~2-3 minutes for cloud-init to complete
sleep 180

# 7. Sign certificate on Puppet server
ssh pi.ra-home.co.uk
sudo puppetserver ca sign --certname web03.ra-home.co.uk
exit

# 8. Connect and verify
ssh ryan@$IP
sudo puppet agent -t
```

## Example 2: VPS with Monitoring Stack

**Scenario:** Deploy a VPS with WireGuard VPN, monitoring, and Pi-hole

```bash
# 1. Generate cloud-init with WireGuard
./customize.sh
# Choose: (2) vps
# Hostname: monitor01
# SSH Key: (1) Use default
# Generate WireGuard keys: y
# VPN IP: 10.10.10.25
# Server IP: <your-vps-ip>
# Server public key: <from server>

# Script outputs peer config - save it!

# 2. Update VPS WireGuard peers
vim data/nodes/vps.ra-home.co.uk.yaml
# Add peer configuration from script output under profile::wireguard::peers

# 3. Create node config for monitoring role
cat >> manifests/site.pp <<'EOF'

node 'monitor01.ra-home.co.uk' {
  include role::vps
}
EOF

# 4. Create Hiera with monitoring overrides
cat > data/nodes/monitor01.ra-home.co.uk.yaml <<'EOF'
---
# VPS configuration
profile::base::manage_firewall: false  # Using UFW instead

# Monitoring
profile::monitoring::manage_monitoring: true
profile::monitoring::monitoring_dir: '/opt/monitoring'
profile::monitoring::enable_victoriametrics: true
profile::monitoring::enable_grafana: true
profile::monitoring::enable_loki: true
profile::monitoring::enable_promtail: true

# WireGuard
profile::wireguard::manage_wireguard: true
profile::wireguard::vpn_network: '10.10.10.0/24'
EOF

# 5. Commit and apply to VPS server first (to add peer)
git add data/nodes/vps.ra-home.co.uk.yaml data/nodes/monitor01.ra-home.co.uk.yaml manifests/site.pp
git commit -m "Add monitor01 VPS with WireGuard peer"
git push

ssh vps.ra-home.co.uk
sudo puppet agent -t  # Adds WireGuard peer
exit

# 6. Deploy new VPS
linode-cli linodes create \
  --label monitor01 \
  --image linode/rocky9 \
  --type g6-standard-2 \
  --region us-east \
  --metadata.user_data "$(base64 -w0 generated/monitor01.yaml)"

# 7. Wait and verify WireGuard from VPS
sleep 180
ssh vps.ra-home.co.uk
sudo wg show  # Should see monitor01 peer
ping 10.10.10.25  # Should work once host is up
exit

# 8. Sign certificate
ssh pi.ra-home.co.uk
sudo puppetserver ca sign --certname monitor01.ra-home.co.uk
exit

# 9. Connect via VPN and run Puppet
ssh ryan@10.10.10.25
sudo puppet agent -t
```

## Example 3: Batch Provisioning Multiple Hosts

**Scenario:** Deploy 3 development hosts at once

```bash
# 1. Create a batch script
cat > deploy-dev-hosts.sh <<'EOF'
#!/bin/bash
set -e

HOSTS=("dev01" "dev02" "dev03")
BASE_IP=30

for HOST in "${HOSTS[@]}"; do
  echo "Generating config for $HOST..."

  # Generate cloud-init
  cp cloud-init/base.yaml "generated/${HOST}.yaml"
  sed -i "s/YOUR_HOSTNAME/$HOST/g" "generated/${HOST}.yaml"
  sed -i "s|YOUR_SSH_PUBLIC_KEY_HERE|$(cat ~/.ssh/id_rsa.pub)|g" "generated/${HOST}.yaml"

  # Add to site.pp
  echo "
node '${HOST}.ra-home.co.uk' {
  include role::base
}" >> manifests/site.pp

  # Create basic Hiera
  cat > "data/nodes/${HOST}.ra-home.co.uk.yaml" <<HIERA
---
# Development host $HOST
profile::base::manage_firewall: true
HIERA

  echo "Deploying $HOST to DigitalOcean..."
  doctl compute droplet create "${HOST}.ra-home.co.uk" \
    --image rockylinux-9-x64 \
    --size s-1vcpu-1gb \
    --region nyc3 \
    --user-data-file "generated/${HOST}.yaml" &
done

wait
echo "All hosts deploying!"

# Commit Puppet changes
git add manifests/site.pp data/nodes/
git commit -m "Add dev hosts: ${HOSTS[*]}"
git push

echo "Wait 3 minutes for cloud-init, then sign certificates..."
sleep 180

echo "
Sign certificates with:
  ssh pi.ra-home.co.uk
  for host in ${HOSTS[@]}; do
    sudo puppetserver ca sign --certname \${host}.ra-home.co.uk
  done
"
EOF

chmod +x deploy-dev-hosts.sh
./deploy-dev-hosts.sh
```

## Example 4: ProxmoxVE Local Development

**Scenario:** Create local dev VMs in Proxmox

```bash
# 1. Generate cloud-init
./customize.sh
# Choose: (1) base
# Hostname: testvm
# SSH Key: (1) Use default

# 2. Upload to Proxmox
scp generated/testvm.yaml root@proxmox:/var/lib/vz/snippets/testvm-cloud-init.yaml

# 3. Create VM with cloud-init
ssh root@proxmox

# Create VM from Rocky 9 template (ID 9000)
qm clone 9000 101 --name testvm
qm set 101 --cicustom "user=local:snippets/testvm-cloud-init.yaml"
qm set 101 --ipconfig0 ip=192.168.1.101/24,gw=192.168.1.1
qm set 101 --nameserver 192.168.1.1
qm set 101 --searchdomain ra-home.co.uk
qm start 101

exit

# 4. Wait for boot and cloud-init
sleep 120

# 5. Connect and verify
ssh ryan@192.168.1.101
cloud-init status --long
```

## Example 5: Recovery/Rebuild Host

**Scenario:** Rebuild a failed host with same configuration

```bash
# Assuming host 'web01' failed and needs rebuild

# 1. Destroy old host
doctl compute droplet delete web01.ra-home.co.uk

# 2. Clean up Puppet certificate
ssh pi.ra-home.co.uk
sudo puppetserver ca clean --certname web01.ra-home.co.uk
exit

# 3. Regenerate cloud-init (or reuse if saved)
./customize.sh
# OR: cp generated/web01.yaml /tmp/rebuild.yaml

# 4. Redeploy with same config
doctl compute droplet create web01.ra-home.co.uk \
  --image rockylinux-9-x64 \
  --size s-2vcpu-2gb \
  --region nyc3 \
  --user-data-file generated/web01.yaml \
  --wait

# 5. Sign new certificate
sleep 180
ssh pi.ra-home.co.uk
sudo puppetserver ca sign --certname web01.ra-home.co.uk
exit

# 6. Connect and run Puppet
# Hiera config still exists, so full config will apply
IP=$(doctl compute droplet list --format Name,PublicIPv4 | grep web01 | awk '{print $2}')
ssh ryan@$IP
sudo puppet agent -t
```

## Example 6: Testing Cloud-Init Locally

**Scenario:** Test cloud-init config before deploying

```bash
# Option 1: Use cloud-init schema validator
cloud-init schema --config-file generated/myhost.yaml

# Option 2: Test in local VM (multipass)
multipass launch rocky --name test-cloud-init \
  --cloud-init generated/myhost.yaml

# Wait for cloud-init
sleep 120

# Check status
multipass exec test-cloud-init -- cloud-init status --long

# Verify Puppet
multipass exec test-cloud-init -- sudo puppet agent -t

# Clean up
multipass delete test-cloud-init
multipass purify
```

## Example 7: Custom Network Configuration

**Scenario:** Deploy host with static IP and custom DNS

```bash
# 1. Generate base config
./customize.sh

# 2. Add network config section to cloud-init
cat >> generated/myhost.yaml <<'EOF'

# Network configuration (static IP)
network:
  version: 2
  ethernets:
    eth0:
      addresses:
        - 192.168.1.50/24
      gateway4: 192.168.1.1
      nameservers:
        addresses:
          - 192.168.1.1
          - 1.1.1.1
        search:
          - ra-home.co.uk
EOF

# Deploy as usual
```

## Common Patterns

### Pattern 1: Pre-install Additional Packages

Add to cloud-init `packages:` section:
```yaml
packages:
  - docker-ce
  - docker-compose
  - nginx
  - postgresql
```

### Pattern 2: Run Custom Script on First Boot

Add to cloud-init `write_files:` and `runcmd:`:
```yaml
write_files:
  - path: /tmp/custom-setup.sh
    content: |
      #!/bin/bash
      # Your custom logic
      echo "Running custom setup..."
    permissions: '0755'

runcmd:
  - bash /tmp/custom-setup.sh
```

### Pattern 3: Set Custom Facts for Puppet

```yaml
write_files:
  - path: /etc/puppetlabs/facter/facts.d/custom.yaml
    content: |
      ---
      datacenter: nyc3
      environment: production
      team: platform
```

## Troubleshooting Examples

### Debug cloud-init not completing

```bash
# SSH to host (may need to use password if cloud-init failed)
ssh root@<IP>

# Check status
cloud-init status --long

# View logs
tail -100 /var/log/cloud-init-output.log
journalctl -u cloud-init -n 100

# Re-run specific stages
cloud-init init
cloud-init modules --mode config
cloud-init modules --mode final
```

### Puppet agent not connecting

```bash
# Check DNS resolution
nslookup pi.ra-home.co.uk

# Check connectivity
telnet pi.ra-home.co.uk 8140

# Check certificate
puppet agent --fingerprint

# Check logs
journalctl -u puppet -n 50
```

### WireGuard debugging

```bash
# Check interface
ip addr show wg0

# Check configuration
sudo wg show

# Test connectivity
ping 10.10.10.1

# Check logs
journalctl -u wg-quick@wg0 -n 50

# Manual start
sudo wg-quick down wg0
sudo wg-quick up wg0
```
