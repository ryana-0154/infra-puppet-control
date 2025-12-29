# Encrypted Secrets for pi.ra-home.co.uk

This document describes the eyaml-encrypted secrets that must be generated for the Foreman ENC deployment on pi.ra-home.co.uk.

## Required Secrets

The following placeholders in `data/nodes/pi.ra-home.co.uk.yaml` must be replaced with actual eyaml-encrypted values:

### 1. PostgreSQL Database Password

```bash
# Generate a secure 32-character password for the PostgreSQL foreman user
pwgen -s 32 1 | eyaml encrypt -s
```

Replace `CHANGEME_GENERATE_WITH_EYAML` in:
- `profile::postgresql::database_users.foreman.password` (plaintext password, PostgreSQL will hash it)
- `profile::foreman::db_password` (use the SAME encrypted value)

**Important**: Both must use the **same** encrypted plaintext password. PostgreSQL will automatically hash the password when creating the user.

### 2. Foreman Admin Password

```bash
# Generate a secure 24-character password for the Foreman admin user
pwgen -s 24 1 | eyaml encrypt -s
```

Replace `CHANGEME_GENERATE_WITH_EYAML` in:
- `profile::foreman::admin_password`

**Important**: Save this password securely - you'll need it to log into the Foreman web UI at https://pi.ra-home.co.uk

### 3. OAuth Consumer Credentials

```bash
# Generate OAuth consumer key
uuidgen | eyaml encrypt -s

# Generate OAuth consumer secret
uuidgen | eyaml encrypt -s
```

Replace `CHANGEME_GENERATE_WITH_EYAML` in:
- `profile::foreman_proxy::oauth_consumer_key`
- `profile::foreman_proxy::oauth_consumer_secret`

## Example Workflow

```bash
# 1. Generate PostgreSQL password
DB_PASS=$(pwgen -s 32 1)
echo $DB_PASS | eyaml encrypt -s
# Copy the ENC[PKCS7,...] output

# 2. Generate Foreman admin password
ADMIN_PASS=$(pwgen -s 24 1)
echo "Save this admin password: $ADMIN_PASS"
echo $ADMIN_PASS | eyaml encrypt -s
# Copy the ENC[PKCS7,...] output

# 3. Generate OAuth credentials
uuidgen | eyaml encrypt -s  # consumer_key
uuidgen | eyaml encrypt -s  # consumer_secret
# Copy both ENC[PKCS7,...] outputs

# 4. Edit the Hiera file with encrypted values
eyaml edit data/nodes/pi.ra-home.co.uk.yaml
```

## Security Notes

- Never commit unencrypted passwords to git
- Store the Foreman admin password in your password manager
- The PostgreSQL password must match between `database_users` and `db_password`
- OAuth credentials link the Smart Proxy to the Foreman server
- All secrets use PKCS7 encryption with your eyaml public/private key pair

## Verification

After updating the secrets, verify the file:

```bash
# Decrypt to check values (without saving)
eyaml decrypt -f data/nodes/pi.ra-home.co.uk.yaml

# Validate YAML syntax
ruby -ryaml -e "YAML.load_file('data/nodes/pi.ra-home.co.uk.yaml')"
```

## Deployment Checklist

Before deploying to pi.ra-home.co.uk:

- [ ] All 4 secret placeholders replaced with encrypted values
- [ ] PostgreSQL password matches in both locations
- [ ] Foreman admin password saved securely
- [ ] YAML file validates without errors
- [ ] File committed to git (encrypted values only)
- [ ] Ready to run: `puppet apply --environment production`
