# Cloud-Init Configuration Index

## Files Overview

```
cloud-init/
├── README.md              # Comprehensive documentation (start here)
├── QUICKSTART.md          # Fast-track guide for impatient operators
├── INDEX.md               # This file - directory overview
├── examples.md            # Real-world deployment examples
├── .gitignore             # Prevents committing generated configs
│
├── Templates (customize before use):
├── base.yaml              # Basic Puppet-managed Rocky 9 host
├── vps.yaml               # VPS with WireGuard VPN client
├── foreman-client.yaml    # Foreman ENC-managed host
│
└── Tools:
    ├── customize.sh       # Interactive customization helper
    └── generated/         # Output directory (gitignored)
```

## Quick Reference

### For the Impatient

```bash
# Generate customized config
./customize.sh

# Deploy to DigitalOcean
doctl compute droplet create myhost.ra-home.co.uk \
  --image rockylinux-9-x64 \
  --size s-1vcpu-1gb \
  --region nyc3 \
  --user-data-file generated/myhost.yaml

# Sign certificate (on Puppet server)
ssh pi.ra-home.co.uk
sudo puppetserver ca sign --certname myhost.ra-home.co.uk
```

### For the Methodical

1. Read [QUICKSTART.md](QUICKSTART.md)
2. Review [README.md](README.md)
3. Study [examples.md](examples.md)
4. Customize template or use `customize.sh`
5. Deploy to cloud provider
6. Sign Puppet certificate
7. Verify with `puppet agent -t`

## Template Selection Guide

| Template | Best For | Includes |
|----------|----------|----------|
| **base.yaml** | - General purpose servers<br>- Development boxes<br>- Internal services | - Puppet 7 agent<br>- SSH hardening<br>- fail2ban<br>- Automatic updates |
| **vps.yaml** | - Public VPS instances<br>- Internet-facing services<br>- Remote monitoring | - Everything in base<br>- WireGuard VPN client<br>- UFW firewall<br>- VPN auto-connect |
| **foreman-client.yaml** | - Foreman-managed infrastructure<br>- Large deployments<br>- Centralized ENC | - Everything in base<br>- Foreman integration<br>- ENC node classifier<br>- Report upload |

## Common Workflows

### Workflow 1: Single Host (Manual)
```bash
1. Copy template          → cp base.yaml /tmp/myhost.yaml
2. Edit placeholders      → vim /tmp/myhost.yaml
3. Deploy to cloud        → doctl/aws/gcp/etc
4. Sign certificate       → puppetserver ca sign
5. Run Puppet             → puppet agent -t
```

### Workflow 2: Single Host (Helper Script)
```bash
1. Run helper             → ./customize.sh
2. Deploy to cloud        → Use generated/myhost.yaml
3. Sign certificate       → puppetserver ca sign
4. Run Puppet             → puppet agent -t
```

### Workflow 3: Batch Deployment
```bash
1. Create deployment script → See examples.md
2. Loop through hosts       → for host in hosts; do...
3. Commit Puppet changes    → git commit
4. Deploy all hosts         → Parallel cloud API calls
5. Sign all certificates    → for host in hosts; do...
```

### Workflow 4: VPS with VPN
```bash
1. Generate config          → ./customize.sh (choose vps)
2. Add peer to Puppet       → Edit data/nodes/vps.ra-home.co.uk.yaml
3. Apply Puppet on VPS      → puppet agent -t (on VPS server)
4. Deploy new host          → Use generated/myhost.yaml
5. Verify VPN               → ping 10.10.10.1
6. Sign certificate         → puppetserver ca sign
7. Run Puppet               → puppet agent -t
```

## Customization Checklist

Before deploying ANY cloud-init configuration, ensure you have:

- [ ] Set hostname (YOUR_HOSTNAME)
- [ ] Added SSH public key (YOUR_SSH_PUBLIC_KEY_HERE)
- [ ] Reviewed Puppet server address (pi.ra-home.co.uk)
- [ ] For VPS: Generated WireGuard keys
- [ ] For VPS: Configured server peer in Puppet
- [ ] For VPS: Set VPN IP address
- [ ] Added node to manifests/site.pp (if needed)
- [ ] Created Hiera data in data/nodes/ (if needed)
- [ ] Committed Puppet changes
- [ ] Tested YAML syntax: `python3 -c "import yaml; yaml.safe_load(open('file.yaml'))"`

## Cloud Provider Quick Commands

### DigitalOcean
```bash
doctl compute droplet create HOST \
  --image rockylinux-9-x64 \
  --size s-1vcpu-1gb \
  --region nyc3 \
  --user-data-file generated/HOST.yaml
```

### Linode
```bash
linode-cli linodes create \
  --label HOST \
  --image linode/rocky9 \
  --type g6-nanode-1 \
  --region us-east \
  --metadata.user_data "$(base64 -w0 generated/HOST.yaml)"
```

### Vultr
```bash
vultr-cli instance create \
  --region ewr \
  --plan vc2-1c-1gb \
  --os 542 \
  --userdata="$(cat generated/HOST.yaml)"
```

### AWS EC2
```bash
aws ec2 run-instances \
  --image-id ami-XXXXXXXXX \
  --instance-type t3.micro \
  --user-data file://generated/HOST.yaml
```

### Proxmox
```bash
scp generated/HOST.yaml root@proxmox:/var/lib/vz/snippets/
qm set VMID --cicustom "user=local:snippets/HOST.yaml"
```

### IONOS
```bash
ionosctl server create --datacenter-id <DC_ID> \
  --name HOST --cores 2 --ram 2048 --image-alias rocky:9 \
  --user-data-file generated/HOST.yaml --wait
```
*See [IONOS.md](IONOS.md) for detailed setup*

## Puppet Integration

### Node Classification (manifests/site.pp)
```puppet
node 'newhost.ra-home.co.uk' {
  include role::base
}
```

### Hiera Data (data/nodes/newhost.ra-home.co.uk.yaml)
```yaml
---
profile::base::manage_firewall: true
```

### Certificate Signing
```bash
# List pending certificates
sudo puppetserver ca list

# Sign specific host
sudo puppetserver ca sign --certname newhost.ra-home.co.uk

# Sign all pending
sudo puppetserver ca sign --all
```

## Validation & Testing

### Validate YAML Syntax
```bash
# Using Python
python3 -c "import yaml; yaml.safe_load(open('generated/HOST.yaml'))"

# Using cloud-init (if installed)
cloud-init schema --config-file generated/HOST.yaml
```

### Test Locally (Multipass)
```bash
multipass launch rocky --name test \
  --cloud-init generated/HOST.yaml

multipass exec test -- cloud-init status --long
multipass exec test -- sudo puppet agent -t

multipass delete test && multipass purify
```

### Verify Deployment
```bash
# Check cloud-init status
ssh HOST cloud-init status --long

# View logs
ssh HOST tail -f /var/log/cloud-init-output.log

# Test Puppet
ssh HOST sudo puppet agent -t --debug

# Check services
ssh HOST systemctl status puppet
```

## Troubleshooting Quick Reference

| Issue | Check | Fix |
|-------|-------|-----|
| Cloud-init not running | `cloud-init status` | Verify cloud-init installed: `rpm -q cloud-init` |
| Puppet not connecting | `telnet pi.ra-home.co.uk 8140` | Check firewall, DNS, routing |
| Certificate not signing | `puppet agent --fingerprint` | Sign on server: `puppetserver ca sign` |
| WireGuard not up | `wg show` | Check peer config, firewall, keys |
| SSH key not working | `cat ~/.ssh/authorized_keys` | Verify key in cloud-init |

## Security Best Practices

1. **Never commit generated/ directory** - May contain keys
2. **Use unique WireGuard keys per host** - Never reuse
3. **Enable Puppet certificate manual signing** - No auto-sign in production
4. **Rotate SSH keys regularly** - Update cloud-init templates
5. **Encrypt secrets with eyaml** - For WireGuard PSK in Puppet
6. **Review generated configs** - Before deploying to production
7. **Test in development first** - Use staging environment

## Support & Documentation

- **Cloud-init**: https://cloudinit.readthedocs.io/
- **Puppet**: https://puppet.com/docs/puppet/latest/
- **WireGuard**: https://www.wireguard.com/quickstart/
- **Rocky Linux**: https://docs.rockylinux.org/

## Version History

- **v1.0** (2024-12-30): Initial release
  - Base, VPS, and Foreman templates
  - Interactive customization helper
  - Rocky Linux 9 support
  - WireGuard VPN integration
  - Comprehensive documentation

## Next Steps

1. **Start here**: [QUICKSTART.md](QUICKSTART.md)
2. **Learn more**: [README.md](README.md)
3. **See examples**: [examples.md](examples.md)
4. **Deploy a test host**: `./customize.sh`

---

**Note:** All templates are designed for Rocky Linux 9 but include compatibility checks for Debian-family systems. The Puppet bootstrap script will auto-detect the OS family and install the appropriate Puppet 7 repository.
