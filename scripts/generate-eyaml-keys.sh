#!/bin/bash
# Generate eyaml encryption keys

set -e

KEYS_DIR="$(cd "$(dirname "$0")/../keys" && pwd)"

echo "=== eyaml Key Generation ==="
echo

if [ -f "$KEYS_DIR/private_key.pkcs7.pem" ] || [ -f "$KEYS_DIR/public_key.pkcs7.pem" ]; then
    echo "WARNING: Keys already exist!"
    echo
    echo "Existing keys found:"
    [ -f "$KEYS_DIR/private_key.pkcs7.pem" ] && echo "  - private_key.pkcs7.pem"
    [ -f "$KEYS_DIR/public_key.pkcs7.pem" ] && echo "  - public_key.pkcs7.pem"
    echo
    read -p "Do you want to overwrite them? (yes/no): " -r
    echo
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        echo "Cancelled. Keys were not overwritten."
        exit 0
    fi
    echo "Overwriting existing keys..."
fi

echo "Generating new eyaml keys in: $KEYS_DIR"
echo

# Generate keys
eyaml createkeys --pkcs7-private-key="$KEYS_DIR/private_key.pkcs7.pem" \
                 --pkcs7-public-key="$KEYS_DIR/public_key.pkcs7.pem"

echo
echo "✓ Keys generated successfully!"
echo
echo "Next steps:"
echo "1. Commit the PUBLIC key to git:"
echo "   git add keys/public_key.pkcs7.pem"
echo "   git commit -m 'Add eyaml public key'"
echo
echo "2. Securely distribute the PRIVATE key to your Puppet servers:"
echo "   - Store in /etc/puppetlabs/puppet/eyaml/ on each server"
echo "   - Set permissions: chmod 0400 private_key.pkcs7.pem"
echo "   - Keep a secure backup (password manager, vault, etc.)"
echo
echo "3. Never commit the private key to git!"
echo
echo "4. To encrypt a value:"
echo "   eyaml encrypt -s 'my_secret_password'"
echo
echo "5. To decrypt a file:"
echo "   eyaml decrypt -f data/common.yaml"
