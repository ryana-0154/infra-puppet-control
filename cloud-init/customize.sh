#!/bin/bash
# Cloud-init customization helper script
# Quickly generates customized cloud-init configurations for new hosts

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${GREEN}=== Cloud-Init Customization Helper ===${NC}\n"

# Get template type
echo "Available templates:"
echo "  1) base      - Basic Puppet-managed host"
echo "  2) vps       - VPS with WireGuard VPN client"
echo "  3) foreman   - Foreman ENC-managed host"
echo
read -p "Select template (1-3): " TEMPLATE_CHOICE

case $TEMPLATE_CHOICE in
  1) TEMPLATE="base" ;;
  2) TEMPLATE="vps" ;;
  3) TEMPLATE="foreman-client" ;;
  *)
    echo -e "${RED}Invalid choice${NC}"
    exit 1
    ;;
esac

TEMPLATE_FILE="$SCRIPT_DIR/${TEMPLATE}.yaml"

if [ ! -f "$TEMPLATE_FILE" ]; then
  echo -e "${RED}Template file not found: $TEMPLATE_FILE${NC}"
  exit 1
fi

# Get hostname
read -p "Enter hostname (e.g., web01): " HOSTNAME

if [ -z "$HOSTNAME" ]; then
  echo -e "${RED}Hostname cannot be empty${NC}"
  exit 1
fi

# Get SSH public key
echo
echo "SSH Public Key:"
echo "  1) Use default (~/.ssh/id_rsa.pub)"
echo "  2) Use specific key (~/.ssh/id_ed25519.pub)"
echo "  3) Enter manually"
read -p "Select option (1-3): " SSH_CHOICE

case $SSH_CHOICE in
  1)
    if [ -f ~/.ssh/id_rsa.pub ]; then
      SSH_KEY=$(cat ~/.ssh/id_rsa.pub)
    else
      echo -e "${RED}~/.ssh/id_rsa.pub not found${NC}"
      exit 1
    fi
    ;;
  2)
    if [ -f ~/.ssh/id_ed25519.pub ]; then
      SSH_KEY=$(cat ~/.ssh/id_ed25519.pub)
    else
      echo -e "${RED}~/.ssh/id_ed25519.pub not found${NC}"
      exit 1
    fi
    ;;
  3)
    echo "Enter your SSH public key:"
    read -r SSH_KEY
    ;;
  *)
    echo -e "${RED}Invalid choice${NC}"
    exit 1
    ;;
esac

# Output file
OUTPUT_FILE="$SCRIPT_DIR/generated/${HOSTNAME}.yaml"
mkdir -p "$SCRIPT_DIR/generated"

# Copy and customize template
cp "$TEMPLATE_FILE" "$OUTPUT_FILE"

# Replace placeholders
sed -i "s/YOUR_HOSTNAME/$HOSTNAME/g" "$OUTPUT_FILE"
sed -i "s|YOUR_SSH_PUBLIC_KEY_HERE|$SSH_KEY|g" "$OUTPUT_FILE"

echo -e "\n${GREEN}Base configuration customized!${NC}"

# VPS-specific customization
if [ "$TEMPLATE" = "vps" ]; then
  echo
  echo -e "${YELLOW}=== WireGuard Configuration ===${NC}"
  echo
  read -p "Do you want to generate new WireGuard keys? (y/n): " GEN_KEYS

  if [ "$GEN_KEYS" = "y" ]; then
    # Generate WireGuard keys
    PRIVATE_KEY=$(wg genkey)
    PUBLIC_KEY=$(echo "$PRIVATE_KEY" | wg pubkey)
    PRESHARED_KEY=$(wg genpsk)

    echo
    echo -e "${GREEN}Generated WireGuard keys:${NC}"
    echo "Private Key: $PRIVATE_KEY"
    echo "Public Key:  $PUBLIC_KEY"
    echo "PSK:         $PRESHARED_KEY"
    echo

    # Get VPN IP
    read -p "Enter VPN IP address (e.g., 10.10.10.10): " VPN_IP

    # Get server details
    read -p "Enter VPN server public IP: " SERVER_IP

    echo
    echo "Enter WireGuard server public key:"
    echo "(Find in data/nodes/vps.ra-home.co.uk.yaml or run 'wg show wg0 public-key' on server)"
    read -r SERVER_PUBLIC_KEY

    # Update cloud-init with WireGuard details
    sed -i "s|WIREGUARD_PRIVATE_KEY|$PRIVATE_KEY|g" "$OUTPUT_FILE"
    sed -i "s|WIREGUARD_SERVER_PUBLIC_KEY|$SERVER_PUBLIC_KEY|g" "$OUTPUT_FILE"
    sed -i "s|WIREGUARD_PRESHARED_KEY|$PRESHARED_KEY|g" "$OUTPUT_FILE"
    sed -i "s|VPS_PUBLIC_IP|$SERVER_IP|g" "$OUTPUT_FILE"
    sed -i "s|10.10.10.X|$VPN_IP|g" "$OUTPUT_FILE"

    echo
    echo -e "${GREEN}WireGuard configuration updated!${NC}"
    echo
    echo -e "${YELLOW}IMPORTANT: Add this peer to your Puppet configuration${NC}"
    echo "File: data/nodes/vps.ra-home.co.uk.yaml"
    echo
    echo "Add under profile::wireguard::peers:"
    echo "  $HOSTNAME:"
    echo "    public_key: '$PUBLIC_KEY'"
    echo "    preshared_key: '$(eyaml encrypt -s "$PRESHARED_KEY" 2>/dev/null | grep 'ENC' || echo "$PRESHARED_KEY (run: eyaml encrypt -s '$PRESHARED_KEY')")'"
    echo "    allowed_ips: '$VPN_IP/32'"
    echo

    # Save peer config to file for easy copy-paste
    PEER_CONFIG_FILE="$SCRIPT_DIR/generated/${HOSTNAME}-peer-config.yaml"
    cat > "$PEER_CONFIG_FILE" <<EOF
# Add this to data/nodes/vps.ra-home.co.uk.yaml under profile::wireguard::peers:

  $HOSTNAME:
    public_key: '$PUBLIC_KEY'
    preshared_key: 'TODO_ENCRYPT_WITH_EYAML'  # Run: eyaml encrypt -s '$PRESHARED_KEY'
    allowed_ips: '$VPN_IP/32'
EOF

    echo "Peer configuration saved to: $PEER_CONFIG_FILE"
  else
    echo -e "${YELLOW}Skipping key generation - remember to manually update WireGuard placeholders in:${NC}"
    echo "  $OUTPUT_FILE"
  fi
fi

echo
echo -e "${GREEN}=== Customization Complete ===${NC}"
echo
echo "Output file: $OUTPUT_FILE"
echo
echo "Next steps:"
echo "  1. Review the generated file: $OUTPUT_FILE"

if [ "$TEMPLATE" = "vps" ]; then
  echo "  2. Add WireGuard peer to Puppet (see above)"
  echo "  3. Commit and deploy Puppet changes"
  echo "  4. Use cloud-init file with your cloud provider"
else
  echo "  2. Use cloud-init file with your cloud provider"
fi

echo
echo "Example deployment commands:"
echo
echo "# DigitalOcean"
echo "doctl compute droplet create $HOSTNAME.ra-home.co.uk \\"
echo "  --image rockylinux-9-x64 \\"
echo "  --size s-1vcpu-1gb \\"
echo "  --region nyc3 \\"
echo "  --user-data-file $OUTPUT_FILE"
echo
echo "# Linode"
echo "linode-cli linodes create \\"
echo "  --label $HOSTNAME \\"
echo "  --image linode/rocky9 \\"
echo "  --type g6-nanode-1 \\"
echo "  --region us-east \\"
echo "  --metadata.user_data \"\$(base64 -w0 $OUTPUT_FILE)\""
echo
echo "# Proxmox (upload file first)"
echo "scp $OUTPUT_FILE root@proxmox:/var/lib/vz/snippets/${HOSTNAME}-cloud-init.yaml"
echo "qm set <VMID> --cicustom \"user=local:snippets/${HOSTNAME}-cloud-init.yaml\""
echo
