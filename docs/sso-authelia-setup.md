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

**IMPORTANT**: The default configuration uses HTTP (port 80) for simplicity. **This is NOT secure for production use.** Authelia sessions can be stolen over unencrypted HTTP connections.

### Current Configuration (HTTP-only)

The provided `nginx.conf.erb` template listens on port 80 only:
```nginx
server {
    listen 80;
    server_name grafana.example.com;
    # ...
}
```

While the redirect URLs reference `https://`, this assumes you have **external TLS termination** (e.g., a load balancer, CDN, or external reverse proxy handling SSL).

### Production Deployment Options

For production, you **must** configure SSL/TLS termination. Choose one of these options:

#### Option 1: External TLS Termination (Recommended for Cloud/CDN)

Use an external service to handle SSL:
- **Cloudflare**: Free SSL with Cloudflare Tunnel (no port forwarding needed)
- **AWS ALB/NLB**: Application or Network Load Balancer with ACM certificates
- **Cloud Load Balancers**: GCP, Azure, or DigitalOcean load balancers

In this setup:
1. External service terminates SSL (HTTPS → HTTP)
2. Nginx receives HTTP traffic from the external service
3. No changes needed to nginx.conf.erb

#### Option 2: Nginx with Let's Encrypt (Recommended for Self-Hosted)

Modify `nginx.conf.erb` to add SSL configuration:

```nginx
server {
    listen 443 ssl http2;
    server_name grafana.example.com;

    ssl_certificate /etc/letsencrypt/live/example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/example.com/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;

    # ... rest of config (auth_request, proxy_pass, etc.)
}

# Redirect HTTP to HTTPS
server {
    listen 80;
    server_name grafana.example.com;
    return 301 https://$server_name$request_uri;
}
```

Obtain certificates using Certbot:
```bash
sudo certbot certonly --standalone -d auth.example.com -d grafana.example.com -d prometheus.example.com -d loki.example.com
```

#### Option 3: Reverse Proxy in Front of Nginx

Use another reverse proxy with automatic HTTPS:
- **Traefik**: Automatic Let's Encrypt with Docker labels
- **Caddy**: Automatic HTTPS by default
- **Nginx Proxy Manager**: Web UI for Let's Encrypt management

In this setup, the external proxy handles SSL and forwards HTTP to the monitoring Nginx container.

### Testing in Development

For **non-production testing only**, you can:
1. Use HTTP with localhost/private IPs
2. Accept the security risk of session theft
3. Use SSH tunneling for secure access: `ssh -L 8080:localhost:80 server`

**Never use HTTP in production or over the internet.**

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

## Redis Security

The default Redis configuration **runs without authentication** and is only accessible via Docker's internal network. This is acceptable for development but should be hardened for production.

### Current Security Posture

- **Network isolation**: Redis only listens on Docker's internal network
- **No authentication**: No password required (default)
- **No encryption**: Traffic between Authelia and Redis is unencrypted
- **Ephemeral storage**: Data stored in Docker volume, persists across restarts

### Production Recommendations

1. **Enable Redis AUTH** (if exposing beyond Docker network):
   ```bash
   # In docker-compose.yaml.erb, add command:
   command: redis-server --requirepass your_strong_password_here
   ```
   Then update Authelia config to use the password.

2. **Limit network exposure**:
   - Keep Redis on internal Docker network only
   - Never expose Redis port (6379) to the host or internet
   - Use Docker network isolation

3. **Enable TLS** (for highly sensitive environments):
   - Configure Redis with TLS certificates
   - Update Authelia config to use `rediss://` (Redis with TLS)

4. **Monitor Redis**:
   ```bash
   # Check Redis memory usage
   docker exec redis redis-cli info memory

   # Monitor connected clients
   docker exec redis redis-cli info clients
   ```

5. **Backup Redis** (optional):
   - Sessions are ephemeral and can be recreated
   - User 2FA devices are stored in SQLite (not Redis)
   - Only sessions would be lost on Redis data loss

### Default Configuration is Acceptable If:

- Redis is NOT exposed outside Docker network
- You're running on a private server (not shared hosting)
- You trust all users with access to the Docker host
- You understand that someone with Docker access can read sessions

## Emergency Access Procedures

If you're locked out of Authelia or encountering authentication issues, use these procedures to regain access.

### Scenario 1: Forgotten Password

**Solution**: Reset password via Hiera

1. Generate new password hash:
   ```bash
   docker run authelia/authelia:4.38 authelia crypto hash generate argon2 --password 'new-password'
   ```

2. Update user's password in Hiera configuration
3. Encrypt with eyaml
4. Apply Puppet configuration: `puppet agent -t`
5. Restart Authelia: `cd /opt/monitoring && docker-compose restart authelia`

### Scenario 2: Lost 2FA Device

**Solution**: Remove 2FA requirement from user database

1. Stop Authelia:
   ```bash
   cd /opt/monitoring
   docker-compose stop authelia
   ```

2. Access Authelia's SQLite database:
   ```bash
   docker run --rm -v monitoring_authelia-data:/data -it alpine sh
   apk add sqlite
   sqlite3 /data/db.sqlite3
   ```

3. Remove user's 2FA devices:
   ```sql
   -- List user's devices
   SELECT * FROM totp_configurations WHERE username = 'admin';
   SELECT * FROM webauthn_devices WHERE username = 'admin';

   -- Delete devices
   DELETE FROM totp_configurations WHERE username = 'admin';
   DELETE FROM webauthn_devices WHERE username = 'admin';

   .quit
   ```

4. Restart Authelia:
   ```bash
   docker-compose start authelia
   ```

5. User can now log in with just password and re-enroll 2FA

### Scenario 3: Complete Lockout (All Admins Locked)

**Solution**: Temporarily disable SSO

1. Update Hiera configuration:
   ```yaml
   profile::monitoring::enable_authelia: false
   profile::monitoring::enable_nginx_proxy: false
   ```

2. Apply configuration:
   ```bash
   puppet agent -t
   cd /opt/monitoring
   docker-compose down
   docker-compose up -d
   ```

3. Services now accessible directly:
   - Grafana: `http://server-ip:3000`
   - Prometheus: `http://server-ip:9090`
   - Loki: `http://server-ip:3100`

4. After regaining access, re-enable SSO and fix authentication issues

### Scenario 4: Nginx Misconfiguration

**Solution**: Access services via direct ports

Even with Nginx proxy enabled, services listen on their original ports within the Docker network:

```bash
# Access via SSH tunnel
ssh -L 3000:localhost:3000 server-hostname

# Then browse to http://localhost:3000 for Grafana
```

Or temporarily stop Nginx:
```bash
docker-compose stop nginx
```

Services remain accessible on their original ports.

### Scenario 5: Redis Session Issues

**Solution**: Restart Redis to clear sessions

```bash
cd /opt/monitoring
docker-compose restart redis authelia
```

All users will be logged out and need to re-authenticate.

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
