# Single Sign-On with Authelia

This guide explains how to configure Authelia SSO for protecting your monitoring stack (Grafana, Prometheus, Loki) with centralized authentication and optional two-factor authentication (2FA).

## Architecture

The SSO setup consists of:

1. **Authelia** - Authentication portal with 2FA support
2. **Nginx** - Reverse proxy that checks authentication before proxying requests
3. **Redis** - Session storage for Authelia (recommended for production)
4. **OIDC Integration** - Grafana knows the authenticated user's identity

## Prerequisites

- A domain name (e.g., `example.com`)
- DNS configured to point to your monitoring server:
  - `auth.example.com` → Authelia portal
  - `grafana.example.com` → Grafana
  - `prometheus.example.com` → Prometheus
  - `loki.example.com` → Loki
- SSL/TLS certificates (recommended - can use Let's Encrypt)

## Quick Start

### 1. Generate Secrets

Authelia requires several random secrets for security. Generate them using:

```bash
# JWT secret (for OIDC tokens)
openssl rand -hex 32

# Session secret
openssl rand -hex 32

# Storage encryption key
openssl rand -hex 32

# Grafana OIDC client secret
openssl rand -hex 32
```

### 2. Generate OIDC Private Key

For OIDC JWT signing:

```bash
openssl genrsa -out oidc_private_key.pem 4096
```

### 3. Generate Password Hashes

Authelia uses Argon2id for password hashing. Generate hashes for your users:

```bash
docker run authelia/authelia:4.38 authelia crypto hash generate argon2 --password 'your-password-here'
```

This will output a hash like:
```
$argon2id$v=19$m=65536,t=3,p=4$...[hash]...
```

### 4. Configure Hiera

Create or update your node-specific Hiera file (e.g., `data/nodes/yournode.yaml`):

```yaml
# Enable SSO components
profile::monitoring::enable_authelia: true
profile::monitoring::enable_nginx_proxy: true
profile::monitoring::enable_redis: true

# Domain configuration
profile::monitoring::domain_name: 'example.com'

# Authelia secrets (ENCRYPT WITH EYAML!)
profile::monitoring::authelia_jwt_secret: >
  ENC[PKCS7,MIIBeQYJKoZIhvcNAQcDoIIBajCCAWYCAQAxggEhMIIBHQIBADAFMAACAQEw...]

profile::monitoring::authelia_session_secret: >
  ENC[PKCS7,MIIBeQYJKoZIhvcNAQcDoIIBajCCAWYCAQAxggEhMIIBHQIBADAFMAACAQEw...]

profile::monitoring::authelia_storage_encryption_key: >
  ENC[PKCS7,MIIBeQYJKoZIhvcNAQcDoIIBajCCAWYCAQAxggEhMIIBHQIBADAFMAACAQEw...]

profile::monitoring::grafana_oidc_secret: >
  ENC[PKCS7,MIIBeQYJKoZIhvcNAQcDoIIBajCCAWYCAQAxggEhMIIBHQIBADAFMAACAQEw...]

profile::monitoring::oidc_private_key: >
  ENC[PKCS7,MIIBeQYJKoZIhvcNAQcDoIIBajCCAWYCAQAxggEhMIIBHQIBADAFMAACAQEw...]

# SSO Users
profile::monitoring::sso_users:
  admin:
    displayname: "Administrator"
    email: "admin@example.com"
    password: "$argon2id$v=19$m=65536,t=3,p=4$..." # Generated hash
    groups:
      - admins
  user1:
    displayname: "John Doe"
    email: "john@example.com"
    password: "$argon2id$v=19$m=65536,t=3,p=4$..." # Generated hash
    groups:
      - users
```

### 5. Encrypt Secrets with eyaml

```bash
# Encrypt each secret
eyaml encrypt -s 'your-jwt-secret-here'
eyaml encrypt -s 'your-session-secret-here'
eyaml encrypt -s 'your-storage-key-here'
eyaml encrypt -s 'your-grafana-oidc-secret-here'

# For the private key, use a file
eyaml encrypt -f oidc_private_key.pem
```

### 6. Apply Configuration

```bash
puppet agent -t
cd /opt/monitoring
docker-compose up -d
```

## Access Control

### Default Policy

The default policy is **deny** - all services require authentication unless explicitly bypassed.

### Two-Factor Authentication

Users are required to set up 2FA on first login. Supported methods:

1. **TOTP** (Time-based One-Time Password) - Apps like Google Authenticator, Authy
2. **WebAuthn** - Hardware keys like YubiKey, Touch ID, Windows Hello
3. **Duo Push** (optional, requires Duo account)

### User Groups and Grafana Roles

Users in the `admins` group automatically get **Admin** role in Grafana.
Other users get **Viewer** role by default.

To customize, modify the `GF_AUTH_GENERIC_OAUTH_ROLE_ATTRIBUTE_PATH` in docker-compose.

## DNS Configuration

Configure your DNS to point to your monitoring server:

```dns
auth.example.com.        A    192.168.1.100
grafana.example.com.     A    192.168.1.100
prometheus.example.com.  A    192.168.1.100
loki.example.com.        A    192.168.1.100
```

Or use a wildcard:
```dns
*.example.com.           A    192.168.1.100
```

## SSL/TLS Setup

For production, configure SSL/TLS termination. Options:

### Option 1: Nginx with Let's Encrypt

Add to nginx configuration:

```nginx
server {
    listen 443 ssl http2;
    server_name grafana.example.com;

    ssl_certificate /etc/letsencrypt/live/example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/example.com/privkey.pem;

    # ... rest of config
}
```

### Option 2: External Reverse Proxy

Use an external proxy like:
- Traefik with automatic Let's Encrypt
- Nginx Proxy Manager
- Caddy with automatic HTTPS

### Option 3: Cloudflare Tunnel

Use Cloudflare Zero Trust tunnels for automatic HTTPS without port forwarding.

## First Login

1. Navigate to `https://grafana.example.com` (or your configured domain)
2. You'll be redirected to Authelia login page
3. Enter your username and password
4. Set up 2FA (TOTP or WebAuthn)
5. After 2FA setup, you'll be redirected to Grafana, automatically logged in

## Managing Users

### Adding Users

Add to Hiera configuration:

```yaml
profile::monitoring::sso_users:
  newuser:
    displayname: "New User"
    email: "newuser@example.com"
    password: "$argon2id$..." # Generated hash
    groups:
      - users
```

Then apply: `puppet agent -t && cd /opt/monitoring && docker-compose restart authelia`

### Resetting Passwords

1. Generate new password hash
2. Update user's password in Hiera
3. Encrypt with eyaml
4. Apply configuration
5. Restart Authelia: `docker-compose restart authelia`

### Disabling Users

Remove the user from `sso_users` hash, apply configuration, and restart Authelia.

## Brute Force Protection

Authelia includes built-in protection:

- **Max retries**: 3 failed attempts
- **Find time**: 2 minutes
- **Ban time**: 5 minutes

After 3 failed login attempts within 2 minutes, the IP is banned for 5 minutes.

## Session Management

- **Session expiration**: 1 hour of activity
- **Inactivity timeout**: 5 minutes
- **Remember me**: 1 month (optional)
- **Session storage**: Redis (survives Authelia restarts)

## Troubleshooting

### Can't Access Services

1. Check Authelia is running:
   ```bash
   docker-compose ps authelia
   docker-compose logs authelia
   ```

2. Check Redis is running:
   ```bash
   docker-compose ps redis
   ```

3. Check Nginx is running:
   ```bash
   docker-compose ps nginx
   docker-compose logs nginx
   ```

### Redirect Loop

- Ensure `domain_name` is correctly configured
- Check DNS resolves correctly
- Verify SSL certificates if using HTTPS

### OIDC Not Working in Grafana

1. Check Grafana logs:
   ```bash
   docker-compose logs grafana | grep -i oauth
   ```

2. Verify `grafana_oidc_secret` matches in both Authelia config and Grafana environment

3. Ensure Grafana's `redirect_uri` in Authelia config matches actual callback URL

### 2FA Issues

If locked out:

1. Stop Authelia: `docker-compose stop authelia`
2. Edit the users file manually: `vim /opt/monitoring/authelia-users.yaml`
3. Remove 2FA devices for the user (if present)
4. Restart: `docker-compose start authelia`

### Session Not Persisting

- Check Redis is running and accessible
- Verify Redis connection in Authelia config
- Check Redis logs: `docker-compose logs redis`

## Security Best Practices

1. **Always use HTTPS in production** - Authelia sessions can be stolen over HTTP
2. **Enable 2FA for all users** - Especially admin accounts
3. **Use strong passwords** - Minimum 12 characters, mixed case, numbers, symbols
4. **Rotate secrets periodically** - Update JWT, session, and storage encryption keys
5. **Monitor authentication logs** - Check for suspicious login attempts
6. **Keep Authelia updated** - Security patches are important
7. **Backup user database** - The SQLite database in `/config/db.sqlite3`
8. **Use eyaml for all secrets** - Never commit plaintext secrets

## Monitoring Authelia

View authentication activity:

```bash
# Real-time logs
docker-compose logs -f authelia

# Failed login attempts
docker-compose logs authelia | grep -i "authentication failed"

# Successful logins
docker-compose logs authelia | grep -i "authentication successful"
```

Add to Loki for log aggregation (already configured if Promtail is enabled).

## Advanced Configuration

### Custom Access Control Rules

Edit the `access_control` section in `authelia-config.yaml.erb`:

```yaml
access_control:
  rules:
    # Allow public access to specific endpoint
    - domain: "status.example.com"
      policy: bypass

    # Require single-factor for specific service
    - domain: "prometheus.example.com"
      policy: one_factor
      subject: "group:admins"

    # Require 2FA for sensitive services
    - domain: "grafana.example.com"
      policy: two_factor
```

### Email Notifications

To enable email notifications for password resets and security events:

1. Configure SMTP in `authelia-config.yaml.erb`:

```yaml
notifier:
  smtp:
    username: notifications@example.com
    password: <%= @smtp_password %>
    host: smtp.gmail.com
    port: 587
    sender: "Authelia <auth@example.com>"
```

2. Add `smtp_password` parameter to monitoring profile

### Duo Push 2FA

To enable Duo Push:

1. Sign up for Duo account
2. Get API credentials
3. Configure in `authelia-config.yaml.erb`:

```yaml
duo_api:
  disable: false
  hostname: api-xxxxxxxx.duosecurity.com
  integration_key: <%= @duo_integration_key %>
  secret_key: <%= @duo_secret_key %>
```

## Disabling SSO

To disable SSO and return to direct access:

```yaml
profile::monitoring::enable_authelia: false
profile::monitoring::enable_nginx_proxy: false
profile::monitoring::enable_redis: false
```

Apply configuration and access services directly at their original ports.

## References

- [Authelia Documentation](https://www.authelia.com/docs/)
- [Authelia Integration Examples](https://www.authelia.com/integration/prologue/get-started/)
- [OIDC Configuration](https://www.authelia.com/configuration/identity-providers/open-id-connect/)
