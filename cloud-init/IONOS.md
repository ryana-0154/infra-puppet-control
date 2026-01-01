# Cloud-Init Deployment with IONOS

## IONOS Cloud Quick Start

IONOS Cloud supports cloud-init through their Cloud API and DCD (Data Center Designer).

### Prerequisites

```bash
# Install IONOS Cloud CLI
pip3 install ionosctl

# Configure authentication
ionosctl login
# Or set environment variables:
export IONOS_USERNAME="your-email@example.com"
export IONOS_PASSWORD="your-password"
export IONOS_TOKEN="your-api-token"  # Preferred method
```

### Method 1: IONOS CLI Deployment

```bash
# 1. Generate your cloud-init config
cd cloud-init
./customize.sh
# Choose template, enter hostname, etc.

# 2. List available data centers
ionosctl datacenter list

# 3. List available Rocky Linux 9 images
ionosctl image list --location us/las | grep -i rocky

# 4. Create server with cloud-init
ionosctl server create \
  --datacenter-id <DATACENTER_ID> \
  --name myhost.ra-home.co.uk \
  --cores 2 \
  --ram 2048 \
  --availability-zone AUTO \
  --image-alias rocky:9 \
  --user-data-file generated/myhost.yaml \
  --wait

# 5. Get server IP
ionosctl server list --datacenter-id <DATACENTER_ID>

# 6. Wait for cloud-init (3-5 minutes)
sleep 180

# 7. Sign Puppet certificate
ssh pi.ra-home.co.uk
sudo puppetserver ca sign --certname myhost.ra-home.co.uk
```

### Method 2: IONOS Cloud API (curl)

```bash
# 1. Generate cloud-init
./customize.sh

# 2. Base64 encode cloud-init
USERDATA=$(base64 -w0 generated/myhost.yaml)

# 3. Create server via API
curl -X POST \
  -H "Authorization: Bearer ${IONOS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "properties": {
      "name": "myhost.ra-home.co.uk",
      "cores": 2,
      "ram": 2048,
      "availabilityZone": "AUTO",
      "userData": "'${USERDATA}'",
      "image": "rocky-9-latest",
      "imagePassword": ""
    }
  }' \
  "https://api.ionos.com/cloudapi/v6/datacenters/${DATACENTER_ID}/servers"
```

### Method 3: IONOS DCD (Web Console)

Since IONOS DCD doesn't have a native cloud-init upload field, use one of these approaches:

**Option A: Custom ISO with cloud-init**
1. Create cloud-init ISO locally:
   ```bash
   # Install required tools
   sudo dnf install -y genisoimage

   # Create cloud-init directory structure
   mkdir -p iso-content/user-data iso-content/meta-data

   # Copy your cloud-init config
   cp generated/myhost.yaml iso-content/user-data

   # Create empty meta-data
   echo "instance-id: myhost-001" > iso-content/meta-data

   # Generate ISO
   genisoimage -output myhost-cloud-init.iso \
     -volid cidata -joliet -rock \
     iso-content/user-data iso-content/meta-data
   ```

2. Upload ISO to IONOS:
   - Log into DCD: https://dcd.ionos.com
   - Go to Images → Upload
   - Upload `myhost-cloud-init.iso`

3. Create server in DCD:
   - Create new server (Rocky Linux 9)
   - Attach the cloud-init ISO as CD-ROM
   - Boot server
   - Cloud-init will read from the ISO

**Option B: Run cloud-init manually after creation**
1. Create Rocky Linux 9 server in DCD (https://dcd.ionos.com)
2. Set root password during creation
3. Boot server and SSH as root
4. Upload and run cloud-init:
   ```bash
   # From your local machine
   scp generated/myhost.yaml root@<SERVER_IP>:/tmp/cloud-init.yaml

   # On the server
   ssh root@<SERVER_IP>

   # Install cloud-init
   dnf install -y cloud-init

   # Run cloud-init with your config
   cloud-init clean
   cloud-init init --file /tmp/cloud-init.yaml
   cloud-init modules --mode config
   cloud-init modules --mode final

   # Reboot to apply all changes
   reboot
   ```

## IONOS-Specific Configuration

### Network Configuration for IONOS

IONOS uses DHCP by default, but you may want static IPs:

```yaml
# Add to your cloud-init file
network:
  version: 2
  ethernets:
    eth0:
      dhcp4: true
      dhcp6: false
```

### IONOS Firewall Rules

IONOS has both platform-level firewalls (in DCD) and host-level (UFW/iptables):

**Platform Firewall (DCD):**
1. Go to DCD → Your Datacenter → Firewall Rules
2. Add rules for:
   - SSH (port from your encrypted config)
   - WireGuard: UDP 51820
   - HTTP/HTTPS (if web server)

**Host Firewall (via cloud-init/Puppet):**
- Managed by Puppet profiles (already configured in your setup)
- VPS template includes UFW
- Base template uses puppetlabs-firewall

### IONOS VPS with WireGuard Example

```bash
# 1. Generate VPS cloud-init with WireGuard
./customize.sh
# Select: (2) vps
# Hostname: ionos-vps01
# Generate WireGuard keys: y
# VPN IP: 10.10.10.30
# Server IP: <your-existing-vps-public-ip>

# 2. Add peer to existing VPS
vim ../data/nodes/vps.ra-home.co.uk.yaml
# Add peer config from customize.sh output

# 3. Commit and apply Puppet on existing VPS
cd ..
git add data/nodes/vps.ra-home.co.uk.yaml
git commit -m "Add WireGuard peer for ionos-vps01"
git push

ssh vps.ra-home.co.uk
sudo puppet agent -t  # Adds new peer
exit

# 4. Create IONOS server
cd cloud-init
ionosctl server create \
  --datacenter-id <DC_ID> \
  --name ionos-vps01.ra-home.co.uk \
  --cores 2 \
  --ram 2048 \
  --image-alias rocky:9 \
  --user-data-file generated/ionos-vps01.yaml \
  --wait

# 5. Get IP and configure DCD firewall
IONOS_IP=$(ionosctl server list --datacenter-id <DC_ID> | grep ionos-vps01 | awk '{print $X}')
echo "Server IP: $IONOS_IP"

# Configure firewall in DCD for this server:
# - Allow SSH (your custom port)
# - Allow WireGuard UDP 51820

# 6. Wait for cloud-init and verify VPN
sleep 180
ssh vps.ra-home.co.uk
ping 10.10.10.30  # Should work
sudo wg show  # Should show ionos-vps01 peer
exit

# 7. Sign certificate
ssh pi.ra-home.co.uk
sudo puppetserver ca sign --certname ionos-vps01.ra-home.co.uk
exit

# 8. Connect via VPN and run Puppet
ssh ryan@10.10.10.30
sudo puppet agent -t
```

## IONOS Regions and Images

### Available Regions
```bash
# List IONOS locations
ionosctl location list

# Common locations:
# - us/las (Las Vegas, USA)
# - us/ewr (New York, USA)
# - de/fra (Frankfurt, Germany)
# - de/txl (Berlin, Germany)
# - gb/lhr (London, UK)
```

### Rocky Linux 9 Images
```bash
# Find Rocky 9 image
ionosctl image list --location us/las | grep -i rocky

# Or use image alias
--image-alias rocky:9
```

## IONOS Server Sizes

Common configurations:

| Type | Cores | RAM | Use Case | Cost Estimate |
|------|-------|-----|----------|---------------|
| S | 1 | 1GB | Testing, small apps | ~€5/month |
| M | 2 | 2GB | Development, small production | ~€10/month |
| L | 4 | 4GB | Production apps | ~€20/month |
| XL | 8 | 8GB | High traffic apps | ~€40/month |

```bash
# Small server
ionosctl server create \
  --cores 1 --ram 1024 \
  ...

# Recommended for production
ionosctl server create \
  --cores 2 --ram 2048 \
  ...
```

## IONOS-Specific Troubleshooting

### Cloud-init not running on IONOS

IONOS Rocky Linux images should have cloud-init pre-installed, but verify:

```bash
# SSH to server (use console if SSH not working)
ssh root@<IP>

# Check cloud-init installed
rpm -q cloud-init

# If not installed:
dnf install -y cloud-init

# Check if user-data was provided
cat /var/lib/cloud/instance/user-data.txt

# Re-run cloud-init if needed
cloud-init clean
cloud-init init
cloud-init modules --mode config
cloud-init modules --mode final
```

### Serial Console Access

If SSH fails, use IONOS Remote Console:
1. Go to DCD → Your Server → Remote Console
2. Log in as root (using password set during creation)
3. Debug cloud-init: `cat /var/log/cloud-init.log`

### Network Issues

IONOS sometimes has specific network requirements:

```bash
# Check network config
ip addr show
ip route show

# IONOS uses DHCP by default
cat /etc/sysconfig/network-scripts/ifcfg-eth0

# Restart networking if needed
systemctl restart NetworkManager
```

## Complete IONOS Deployment Example

Deploying a complete infrastructure:

```bash
#!/bin/bash
# deploy-to-ionos.sh

set -e

DATACENTER_ID="your-datacenter-id"
LOCATION="us/las"

# 1. Generate configs for 3 servers
for i in 1 2 3; do
  echo "Generating config for ionos-web0${i}..."

  # Create customized cloud-init
  cp base.yaml generated/ionos-web0${i}.yaml
  sed -i "s/YOUR_HOSTNAME/ionos-web0${i}/g" generated/ionos-web0${i}.yaml
  sed -i "s|YOUR_SSH_PUBLIC_KEY_HERE|$(cat ~/.ssh/id_rsa.pub)|g" generated/ionos-web0${i}.yaml

  # Add to Puppet
  cat >> ../manifests/site.pp <<EOF

node 'ionos-web0${i}.ra-home.co.uk' {
  include role::webserver
}
EOF
done

# Commit Puppet changes
cd ..
git add manifests/site.pp
git commit -m "Add IONOS web servers"
git push
cd cloud-init

# 2. Deploy all servers
for i in 1 2 3; do
  echo "Deploying ionos-web0${i}..."

  ionosctl server create \
    --datacenter-id ${DATACENTER_ID} \
    --name ionos-web0${i}.ra-home.co.uk \
    --cores 2 \
    --ram 2048 \
    --availability-zone AUTO \
    --image-alias rocky:9 \
    --user-data-file generated/ionos-web0${i}.yaml \
    --wait &
done

wait
echo "All servers deployed!"

# 3. Wait for cloud-init
echo "Waiting 3 minutes for cloud-init to complete..."
sleep 180

# 4. Sign all certificates
ssh pi.ra-home.co.uk <<'EOSSH'
for i in 1 2 3; do
  sudo puppetserver ca sign --certname ionos-web0${i}.ra-home.co.uk
done
EOSSH

echo "Deployment complete!"
echo "Servers should now be managed by Puppet."
```

## IONOS + Foreman Integration

If using Foreman on pi.ra-home.co.uk:

```bash
# 1. Use foreman-client template
./customize.sh
# Choose: (3) foreman

# 2. Configure Foreman for IONOS provisioning
# In Foreman UI:
# - Configure → Compute Resources → New Compute Resource
# - Type: IONOS Cloud
# - URL: https://api.ionos.com/cloudapi/v6
# - Token: <your-ionos-api-token>

# 3. Create host in Foreman
# - Hosts → New Host
# - Deploy on: IONOS Cloud
# - Image: Rocky 9
# - Cloud-init: Enabled

# Foreman will handle deployment and certificate auto-signing
```

## Tips for IONOS

1. **Use API tokens instead of password auth** - More secure
2. **Set up DCD firewall rules before deployment** - Prevents lockout
3. **Use availability zones** - Better redundancy with AUTO
4. **Snapshot before changes** - Easy rollback
5. **Monitor costs** - IONOS billing is hourly
6. **Use private networking** - Free internal traffic between servers
7. **Enable backups** - IONOS offers automated backups

## IONOS vs Other Providers

| Feature | IONOS | DigitalOcean | Linode |
|---------|-------|--------------|--------|
| Cloud-init support | ✅ Yes (CLI/API) | ✅ Yes (built-in) | ✅ Yes (built-in) |
| DCD GUI cloud-init | ❌ Workaround needed | ✅ Native | ✅ Native |
| EU data centers | ✅ Multiple | ⚠️ Limited | ⚠️ Limited |
| Pricing | €€ Competitive | €€€ Higher | €€ Competitive |
| CLI tool quality | ⚠️ Basic | ✅ Excellent | ✅ Excellent |

## Resources

- **IONOS Cloud API**: https://api.ionos.com/docs/
- **IONOS CLI**: https://github.com/ionos-cloud/ionosctl
- **DCD Console**: https://dcd.ionos.com
- **IONOS Support**: https://www.ionos.com/help

---

**Recommended approach for IONOS**: Use the CLI/API method with the `customize.sh` helper for best results. The DCD GUI method works but requires more manual steps.
