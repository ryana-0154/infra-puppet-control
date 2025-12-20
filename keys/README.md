# eyaml Keys Directory

This directory stores the eyaml (encrypted YAML) keys used for encrypting sensitive data in Hiera.

## Key Files

- `public_key.pkcs7.pem` - Public key (committed to git, used for encryption)
- `private_key.pkcs7.pem` - Private key (**NOT committed**, used for decryption)

## Generating Keys

To generate a new key pair:

```bash
./scripts/generate-eyaml-keys.sh
```

This will create both keys in this directory.

## Key Management

### Public Key
- **Can and should** be committed to version control
- Needed by developers to encrypt secrets
- Used by `eyaml encrypt` command

### Private Key
- **NEVER commit to version control**
- Only needed on Puppet servers for decryption
- Store securely (password manager, vault, encrypted backup)
- Deploy to Puppet servers at: `/etc/puppetlabs/puppet/eyaml/private_key.pkcs7.pem`

## Using eyaml

### Encrypting a Value

```bash
# Encrypt a string
eyaml encrypt -s 'my_secret_password'

# Encrypt a file
eyaml encrypt -f plaintext_file.txt

# Encrypt using specific keys (if not in default location)
eyaml encrypt -s 'secret' \
  --pkcs7-public-key=keys/public_key.pkcs7.pem \
  --pkcs7-private-key=keys/private_key.pkcs7.pem
```

### Adding Encrypted Data to Hiera

```yaml
# data/common.yaml
profile::database::password: >
  ENC[PKCS7,MIIBeQYJKoZIhvcNAQcDoIIBajCCAWYCAQAxggEhMIIBHQIBADAFMAACAQEw
  ...
  encrypted_content_here
  ...
  gU=]
```

### Decrypting Data

```bash
# Decrypt a file
eyaml decrypt -f data/common.yaml

# Edit an encrypted file (decrypt, edit, re-encrypt)
eyaml edit data/common.yaml
```

### Editing Encrypted Files

The `eyaml edit` command is the recommended way to edit files with encrypted values:

```bash
eyaml edit data/common.yaml
```

This will:
1. Decrypt the file
2. Open it in your `$EDITOR`
3. Re-encrypt it when you save and exit

## Puppet Server Setup

On each Puppet server, ensure:

1. Private key is deployed:
   ```bash
   sudo mkdir -p /etc/puppetlabs/puppet/eyaml
   sudo cp private_key.pkcs7.pem /etc/puppetlabs/puppet/eyaml/
   sudo chmod 0400 /etc/puppetlabs/puppet/eyaml/private_key.pkcs7.pem
   sudo chown puppet:puppet /etc/puppetlabs/puppet/eyaml/private_key.pkcs7.pem
   ```

2. Public key is deployed:
   ```bash
   sudo cp public_key.pkcs7.pem /etc/puppetlabs/puppet/eyaml/
   sudo chmod 0444 /etc/puppetlabs/puppet/eyaml/public_key.pkcs7.pem
   sudo chown puppet:puppet /etc/puppetlabs/puppet/eyaml/public_key.pkcs7.pem
   ```

## Security Best Practices

1. **Never commit the private key** to version control
2. **Rotate keys periodically** (annually or when compromised)
3. **Store private key securely** with restricted access
4. **Use separate keys per environment** if needed (dev/staging/prod)
5. **Audit access** to private keys regularly
6. **Backup private keys** to a secure, encrypted location

## Troubleshooting

### "No key found" errors
- Ensure keys are in the correct location on Puppet servers
- Check file permissions (private key: 0400, public key: 0444)
- Verify ownership (should be `puppet:puppet`)

### "Could not decrypt" errors
- Ensure the correct private key is being used
- Verify the encrypted data was encrypted with the matching public key
- Check that hiera.yaml points to the correct key locations
