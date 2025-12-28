# VPS WireGuard Setup Guide for vps.ra-home.co.uk

This guide walks you through generating WireGuard keys and encrypting them for the vps.ra-home.co.uk node configuration.

## Overview

The Hiera configuration for `vps.ra-home.co.uk` has been set up following the [psyonik.tech guide](https://psyonik.tech/posts/a-guide-for-wireguard-vpn-setup-with-pi-hole-adblock-and-unbound-dns/) with placeholders for:

- **WireGuard server** private key
- **5 VPN clients**: homeserver, desktop, laptop, mobile1, mobile2
- **Pi-hole** web admin password

**Configuration Location:** `data/nodes/vps.ra-home.co.uk.yaml`

## Prerequisites

1. WireGuard tools installed:
   ```bash
   sudo apt install wireguard-tools
   ```

2. eyaml configured with encryption keys:
   ```bash
   # Check if keys exist
   ls -la keys/

   # If not, generate them
   ./scripts/generate-eyaml-keys.sh
   ```

3. Determine your external network interface:
   ```bash
   ip route list default
   # Output example: default via 192.168.1.1 dev eth0
   # The interface is: eth0
   ```

   Update `profile::wireguard::external_interface` in the Hiera file if needed.

## Step 1: Generate WireGuard Server Keys

On the VPS server (vps.ra-home.co.uk):

```bash
# Create a directory for keys
mkdir -p ~/wireguard-keys
cd ~/wireguard-keys

# Generate server keys
wg genkey | tee server.key | wg pubkey > server.pub

echo "Server Private Key:"
cat server.key
echo ""
echo "Server Public Key (save for client configs):"
cat server.pub
```

**IMPORTANT:** The server public key will be needed when configuring clients!

## Step 2: Generate Client Keys

For each of the 5 clients, generate keys:

### Homeserver (10.10.10.10)

```bash
wg genkey | tee homeserver.key | wg pubkey > homeserver.pub
wg genpsk > homeserver.psk

echo "=== Homeserver Keys ==="
echo "Private Key:" && cat homeserver.key
echo "Public Key:" && cat homeserver.pub
echo "Preshared Key:" && cat homeserver.psk
```

### Desktop (10.10.10.11)

```bash
wg genkey | tee desktop.key | wg pubkey > desktop.pub
wg genpsk > desktop.psk

echo "=== Desktop Keys ==="
echo "Private Key:" && cat desktop.key
echo "Public Key:" && cat desktop.pub
echo "Preshared Key:" && cat desktop.psk
```

### Laptop (10.10.10.12)

```bash
wg genkey | tee laptop.key | wg pubkey > laptop.pub
wg genpsk > laptop.psk

echo "=== Laptop Keys ==="
echo "Private Key:" && cat laptop.key
echo "Public Key:" && cat laptop.pub
echo "Preshared Key:" && cat laptop.psk
```

### Mobile1 (10.10.10.13)

```bash
wg genkey | tee mobile1.key | wg pubkey > mobile1.pub
wg genpsk > mobile1.psk

echo "=== Mobile1 Keys ==="
echo "Private Key:" && cat mobile1.key
echo "Public Key:" && cat mobile1.pub
echo "Preshared Key:" && cat mobile1.psk
```

### Mobile2 (10.10.10.14)

```bash
wg genkey | tee mobile2.key | wg pubkey > mobile2.pub
wg genpsk > mobile2.psk

echo "=== Mobile2 Keys ==="
echo "Private Key:" && cat mobile2.key
echo "Public Key:" && cat mobile2.pub
echo "Preshared Key:" && cat mobile2.psk
```

## Step 3: Encrypt Sensitive Keys with eyaml

On your Puppet control repository machine:

### Encrypt Server Private Key

```bash
cd /home/ryan/repos/infra-puppet-control

# Encrypt the server private key
eyaml encrypt -s 'paste_server_private_key_here'
```

Copy the output starting with `ENC[PKCS7,...]` and update in `data/nodes/vps.ra-home.co.uk.yaml`:

```yaml
profile::wireguard::server_private_key: >
  ENC[PKCS7,MIIBeQYJKoZIhvcNAQcDoIIBajCCAWYCAQAxggEhMIIBHQIBADAFMAACAQEw...]
```

### Update Client Public Keys (NOT encrypted)

Client public keys and preshared keys do NOT need to be encrypted in Hiera (they're not as sensitive). Update directly:

```yaml
profile::wireguard::peers:
  homeserver:
    public_key: 'actual_homeserver_public_key_here'
    preshared_key: 'actual_homeserver_preshared_key_here'
    allowed_ips: '10.10.10.10/32'
  desktop:
    public_key: 'actual_desktop_public_key_here'
    preshared_key: 'actual_desktop_preshared_key_here'
    allowed_ips: '10.10.10.11/32'
  # ... and so on for all clients
```

## Step 4: Set Pi-hole Admin Password

```bash
# Encrypt a secure password for Pi-hole web admin
eyaml encrypt -s 'your_secure_pihole_password_here'
```

Update in `data/nodes/vps.ra-home.co.uk.yaml`:

```yaml
profile::pihole_native::pihole_webpassword: >
  ENC[PKCS7,MIIBeQYJKoZIhvcNAQcDoIIBajCCAWYCAQAxggEhMIIBHQIBADAFMAACAQEw...]
```

## Step 5: Deploy Configuration

The configuration is now ready to deploy. Puppet will automatically:
- Install Pi-hole if not present (idempotent - won't reinstall if already installed)
- Configure WireGuard with the keys you've set
- Set up Unbound DNS integration
- Configure all firewall rules via UFW

```bash
cd /home/ryan/repos/infra-puppet-control

# Install Puppet modules
bundle exec r10k puppetfile install

# Test the configuration (dry-run)
sudo puppet agent -t --noop

# Apply the configuration
sudo puppet agent -t
```

## Step 7: Create Client Configuration Files

For each client, create a WireGuard configuration file.

### Example: Homeserver Client Config

Create `homeserver.conf`:

```ini
[Interface]
PrivateKey = <HOMESERVER_PRIVATE_KEY>
Address = 10.10.10.10/32
DNS = 10.10.10.1

[Peer]
PublicKey = <SERVER_PUBLIC_KEY>
PresharedKey = <HOMESERVER_PRESHARED_KEY>
AllowedIPs = 0.0.0.0/0
Endpoint = <VPS_PUBLIC_IP>:51820
PersistentKeepalive = 25
```

Replace:
- `<HOMESERVER_PRIVATE_KEY>` with the homeserver private key
- `<SERVER_PUBLIC_KEY>` with the server public key from Step 1
- `<HOMESERVER_PRESHARED_KEY>` with the homeserver preshared key
- `<VPS_PUBLIC_IP>` with your VPS public IP address

### Desktop Client Config

Create `desktop.conf`:

```ini
[Interface]
PrivateKey = <DESKTOP_PRIVATE_KEY>
Address = 10.10.10.11/32
DNS = 10.10.10.1

[Peer]
PublicKey = <SERVER_PUBLIC_KEY>
PresharedKey = <DESKTOP_PRESHARED_KEY>
AllowedIPs = 0.0.0.0/0
Endpoint = <VPS_PUBLIC_IP>:51820
PersistentKeepalive = 25
```

Repeat for laptop.conf, mobile1.conf, and mobile2.conf with their respective keys and IP addresses.

### Mobile Clients (QR Codes)

For mobile devices, generate QR codes:

```bash
sudo apt install qrencode

# Generate QR code for mobile1
qrencode -t ansiutf8 < mobile1.conf

# Scan with WireGuard mobile app
```

## Step 8: Verify Services

After Puppet applies the configuration:

```bash
# Check WireGuard status
sudo wg show

# Check Pi-hole status
pihole status

# Check Unbound status
sudo systemctl status unbound

# Test DNS resolution through Unbound
dig @127.0.0.1 -p 5353 google.com

# Test DNS resolution through Pi-hole
dig @10.10.10.1 google.com
```

## Step 9: Connect Clients and Test

1. Copy the client config files to each device
2. On Linux/Mac:
   ```bash
   sudo wg-quick up /path/to/client.conf
   ```

3. On mobile: Import via QR code or file

4. Test connectivity:
   ```bash
   # Ping the VPN gateway
   ping 10.10.10.1

   # Check DNS resolution
   nslookup google.com

   # Verify ad blocking (should be blocked)
   nslookup ads.google.com
   ```

5. Check for DNS leaks: https://dnsleaktest.com/

## Accessing Pi-hole Admin Interface

From a connected VPN client:

- URL: http://10.10.10.1/admin
- Password: The password you set in Step 4

## Network Topology

```
┌─────────────────────────────────────────────┐
│         VPS (vps.ra-home.co.uk)            │
│                                             │
│  ┌─────────────┐    ┌─────────────┐       │
│  │  WireGuard  │───▶│   Pi-hole   │       │
│  │ 10.10.10.1  │    │  DNS: 53    │       │
│  │ Port: 51820 │    │             │       │
│  └─────────────┘    └──────┬──────┘       │
│                             │               │
│                      ┌──────▼──────┐       │
│                      │   Unbound   │       │
│                      │ 127.0.0.1   │       │
│                      │ Port: 5353  │       │
│                      └─────────────┘       │
└─────────────────────────────────────────────┘
                      ▲
                      │ VPN Tunnel (WireGuard)
                      │
    ┌─────────────────┴─────────────────┐
    │                                    │
┌───▼────┐  ┌────────┐  ┌────────┐  ┌──▼───┐  ┌────────┐
│homesvr │  │desktop │  │ laptop │  │mobile│  │mobile2 │
│.10     │  │.11     │  │ .12    │  │1 .13 │  │ .14    │
└────────┘  └────────┘  └────────┘  └──────┘  └────────┘
```

## Local DNS Records

The following local DNS records are configured:

- `emby.home.server` → 192.168.1.10 (LAN access)
- `emby.travel.server` → 10.10.10.10 (VPN access via homeserver)
- `torrent.home.server` → 192.168.1.10 (LAN access)
- `torrent.travel.server` → 10.10.10.10 (VPN access via homeserver)

Add more as needed in the `profile::pihole_native::local_dns_records` section.

## Troubleshooting

### WireGuard won't start

```bash
# Check configuration
sudo wg-quick down wg0
sudo wg-quick up wg0

# View logs
journalctl -u wg-quick@wg0 -f
```

### Pi-hole not resolving

```bash
# Check FTL status
sudo systemctl status pihole-FTL

# Check logs
pihole -t

# Restart DNS
pihole restartdns
```

### Clients can't connect

1. Verify UFW allows WireGuard port:
   ```bash
   sudo ufw status
   ```

2. Check if interface is up:
   ```bash
   ip addr show wg0
   ```

3. Verify NAT rules:
   ```bash
   sudo iptables -t nat -L POSTROUTING -v
   ```

## Security Notes

1. **Never commit unencrypted private keys** to version control
2. **Always use eyaml** for sensitive data in Hiera
3. **Securely distribute** client configuration files
4. **Rotate keys periodically** (every 6-12 months)
5. **Monitor Pi-hole logs** for suspicious activity
6. **Keep WireGuard up to date**: `sudo apt update && sudo apt upgrade wireguard`

## References

- [Original Guide](https://psyonik.tech/posts/a-guide-for-wireguard-vpn-setup-with-pi-hole-adblock-and-unbound-dns/)
- [WireGuard Documentation](https://www.wireguard.com/)
- [Pi-hole Documentation](https://docs.pi-hole.net/)
- [eyaml Documentation](https://github.com/voxpupuli/hiera-eyaml)
