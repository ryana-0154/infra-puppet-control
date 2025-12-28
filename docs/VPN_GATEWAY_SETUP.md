# VPN Gateway Setup Guide

This guide explains how to use the `role::vpn_gateway` role to set up a complete WireGuard VPN gateway with Pi-hole ad blocking and Unbound recursive DNS resolver, based on the [psyonik.tech guide](https://psyonik.tech/posts/a-guide-for-wireguard-vpn-setup-with-pi-hole-adblock-and-unbound-dns/).

## Overview

The VPN gateway role provides:

- **WireGuard VPN Server** (`profile::wireguard`): Secure VPN connectivity
- **Pi-hole Native** (`profile::pihole_native`): Network-wide ad blocking
- **Unbound DNS** (`profile::unbound`): Recursive DNS resolver for privacy

## Architecture

```
VPN Clients → WireGuard (10.10.10.1:51820) → Pi-hole (DNS:53) → Unbound (127.0.0.1:5353) → Internet
```

## Prerequisites

1. Ubuntu/Debian-based system (or RHEL/Rocky Linux)
2. Public IP address for WireGuard endpoint
3. Firewall rules allowing UDP port 51820
4. Generate WireGuard keys (see Key Generation below)

## Node Classification

In `manifests/site.pp`, classify your VPN gateway node:

```puppet
node 'vpn-gateway.example.com' {
  include role::vpn_gateway
}
```

## Configuration via Hiera

### Step 1: Generate WireGuard Keys

On the VPN gateway server:

```bash
# Generate server keys
wg genkey | tee server.key | wg pubkey > server.pub

# Generate client keys (repeat for each client)
wg genkey | tee client1.key | wg pubkey > client1.pub
wg genpsk > client1.psk
```

### Step 2: Encrypt Sensitive Data

Encrypt the private keys using eyaml:

```bash
eyaml encrypt -s "$(cat server.key)"
eyaml encrypt -s "$(cat client1.key)"
eyaml encrypt -s "your_pihole_password"
```

### Step 3: Configure Hiera

Create or update `data/nodes/vpn-gateway.example.com.yaml`:

```yaml
---
# WireGuard Configuration
profile::wireguard::manage_wireguard: true
profile::wireguard::vpn_network: '10.10.10.0/24'
profile::wireguard::vpn_server_ip: '10.10.10.1'
profile::wireguard::external_interface: 'eth0'  # Check with: ip route list default
profile::wireguard::listen_port: 51820
profile::wireguard::server_private_key: >
  ENC[PKCS7,MIIBeQYJKoZIhvcNAQcDoIIBajCCAWYCAQAxggEhMIIBHQIBADAFMAACAQEw...]

# WireGuard Peers (VPN clients)
profile::wireguard::peers:
  homeserver:
    public_key: 'homeserver_public_key_here'
    preshared_key: 'homeserver_preshared_key_here'
    allowed_ips: '10.10.10.10/32'
  laptop:
    public_key: 'laptop_public_key_here'
    preshared_key: 'laptop_preshared_key_here'
    allowed_ips: '10.10.10.11/32'
  mobile:
    public_key: 'mobile_public_key_here'
    preshared_key: 'mobile_preshared_key_here'
    allowed_ips: '10.10.10.12/32'

# Pi-hole Configuration
profile::pihole_native::manage_pihole: true
profile::pihole_native::install_pihole: true  # Puppet will auto-install if not present (idempotent)
profile::pihole_native::pihole_interface: 'wg0'
profile::pihole_native::pihole_ipv4_address: '10.10.10.1/24'
profile::pihole_native::pihole_webpassword: >
  ENC[PKCS7,MIIBeQYJKoZIhvcNAQcDoIIBajCCAWYCAQAxggEhMIIBHQIBADAFMAACAQEw...]
profile::pihole_native::upstream_dns_servers:
  - '127.0.0.1#5353'  # Use Unbound

# Local DNS records for internal services
profile::pihole_native::local_dns_records:
  'emby.home.server': '192.168.1.10'
  'emby.travel.server': '10.10.10.10'
  'torrent.home.server': '192.168.1.10'
  'torrent.travel.server': '10.10.10.10'

# Unbound Configuration
profile::unbound::manage_unbound: true
profile::unbound::listen_interface: '127.0.0.1'
profile::unbound::listen_port: 5353
profile::unbound::num_threads: 4
profile::unbound::access_control:
  '127.0.0.1/32': 'allow'
  '10.10.10.0/24': 'allow'
  '0.0.0.0/0': 'refuse'
profile::unbound::enable_ipv6: false
profile::unbound::cache_min_ttl: 1800
profile::unbound::cache_max_ttl: 14400
profile::unbound::enable_prefetch: true
profile::unbound::enable_dnssec: true
```

## Deployment

### 1. Deploy to Puppet Server

```bash
# Install dependencies
bundle exec r10k puppetfile install

# Test the configuration
bundle exec puppet apply --noop \
  --modulepath=modules:site-modules \
  --execute "include role::vpn_gateway"

# Apply the configuration
sudo puppet agent -t
```

### 2. Verify Services

```bash
# Check WireGuard status
sudo wg show

# Check Pi-hole status
pihole status

# Check Unbound status
sudo systemctl status unbound

# Test DNS resolution through Unbound
dig @127.0.0.1 -p 5353 example.com
```

### 3. Access Pi-hole Admin

Open browser to: `http://10.10.10.1/admin` (when connected to VPN)

## Client Configuration

### Generate Client Configuration

Example `client.conf` file:

```ini
[Interface]
PrivateKey = <CLIENT_PRIVATE_KEY>
Address = 10.10.10.11/32
DNS = 10.10.10.1

[Peer]
PublicKey = <SERVER_PUBLIC_KEY>
PresharedKey = <CLIENT_PRESHARED_KEY>
AllowedIPs = 0.0.0.0/0
Endpoint = <VPS_PUBLIC_IP>:51820
PersistentKeepalive = 25
```

### Mobile Clients

Generate QR code for easy import:

```bash
apt install qrencode
qrencode -t ansiutf8 < client.conf
```

Scan with WireGuard mobile app.

### Split Tunneling (Optional)

To exclude local networks from VPN routing, use the WireGuard AllowedIPs Calculator or enable "Exclude private IPs" in the mobile app settings.

## Firewall Rules (UFW)

The `profile::wireguard` profile automatically manages UFW firewall rules for:

- WireGuard port (51820/udp)
- DNS from VPN network (53/tcp,udp)
- HTTP for Pi-hole admin (80/tcp)
- HTTPS (443/tcp)
- UFW routing rules:
  - VPN traffic from wg0 to external interface (eth0)
  - VPN-to-VPN traffic within wg0

The WireGuard interface configuration also includes UFW route commands in PostUp/PreDown hooks, exactly as specified in the guide:

```ini
PostUp = ufw route allow in on wg0 out on eth0
PostUp = iptables -t nat -I POSTROUTING -o eth0 -j MASQUERADE
PreDown = ufw route delete allow in on wg0 out on eth0
PreDown = iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE
```

This ensures proper routing and NAT for VPN traffic.

## Testing

### Verify VPN Connection

```bash
# From client, ping the VPN gateway
ping 10.10.10.1

# Check DNS is working through Pi-hole
nslookup example.com 10.10.10.1

# Verify ad blocking (should be blocked)
nslookup ads.google.com 10.10.10.1
```

### Check for DNS Leaks

Visit https://dnsleaktest.com/ while connected to VPN to verify all DNS queries go through your VPN gateway.

## Troubleshooting

### WireGuard Not Starting

```bash
# Check configuration syntax
sudo wg-quick down wg0
sudo wg-quick up wg0

# View logs
journalctl -u wg-quick@wg0 -f
```

### Pi-hole Not Resolving

```bash
# Check if FTL is running
sudo systemctl status pihole-FTL

# Check logs
pihole -t

# Restart DNS
pihole restartdns
```

### Unbound Not Working

```bash
# Check configuration
sudo unbound-checkconf

# Test resolution
dig @127.0.0.1 -p 5353 example.com

# View logs
journalctl -u unbound -f
```

## Security Considerations

1. **Keep Keys Secure**: Never commit unencrypted private keys to version control
2. **Use eyaml**: All sensitive data should be encrypted in Hiera with eyaml
3. **Update Regularly**: Keep WireGuard, Pi-hole, and Unbound up to date
4. **Monitor Logs**: Regularly review Pi-hole query logs for suspicious activity
5. **Limit Access**: Only allow known client public keys in peer configuration

## Performance Tuning

### For High-Traffic Servers

Increase Unbound threads and cache:

```yaml
profile::unbound::num_threads: 8
profile::unbound::cache_min_ttl: 3600
profile::unbound::cache_max_ttl: 86400
```

### For Low-Memory Systems

Reduce cache sizes in Pi-hole setupVars.conf or decrease Unbound threads.

## References

- [Original Guide](https://psyonik.tech/posts/a-guide-for-wireguard-vpn-setup-with-pi-hole-adblock-and-unbound-dns/)
- [WireGuard Documentation](https://www.wireguard.com/)
- [Pi-hole Documentation](https://docs.pi-hole.net/)
- [Unbound Documentation](https://nlnetlabs.nl/documentation/unbound/)
- [Voxpupuli augeasproviders_sysctl](https://github.com/voxpupuli/puppet-augeasproviders_sysctl)

## Module Files Created

### Profiles
- `site-modules/profile/manifests/wireguard.pp` - WireGuard VPN server management
- `site-modules/profile/manifests/pihole_native.pp` - Native Pi-hole installation
- `site-modules/profile/manifests/unbound.pp` - Unbound DNS resolver (pre-existing)

### Role
- `site-modules/role/manifests/vpn_gateway.pp` - Composes all VPN gateway profiles

### Templates
- `site-modules/profile/templates/wireguard/wg0.conf.erb`
- `site-modules/profile/templates/pihole_native/setupVars.conf.erb`
- `site-modules/profile/templates/pihole_native/custom.list.erb`
- `site-modules/profile/templates/pihole_native/01-pihole.conf.erb`
- `site-modules/profile/templates/unbound/*.erb` (pre-existing)

### Tests
- `site-modules/profile/spec/classes/wireguard_spec.rb`
- `site-modules/profile/spec/classes/pihole_native_spec.rb`
- `site-modules/role/spec/classes/vpn_gateway_spec.rb`

## Updates to Puppetfile

Added the following modules:

**Firewall Management (UFW):**
- `kogitoapp-ufw` (v1.0.3) - UFW firewall management
- `puppetlabs-resource_api` (v1.10.0) - Required by UFW module

**Sysctl Management (Voxpupuli):**
- `puppet-augeasproviders_sysctl` (v4.0.0) - IP forwarding configuration
- `puppet-augeasproviders_core` (v5.0.0) - Core augeas providers

The implementation uses UFW (Uncomplicated Firewall) exactly as specified in the guide, rather than directly managing iptables via puppetlabs-firewall.
