#!/usr/bin/env bash
#
# foreman-backup.sh - Backup Foreman data from pi.ra-home.co.uk
#
# This script creates comprehensive backups of:
# - PostgreSQL foreman database
# - Foreman configuration files
# - SSL certificates
# - Puppet SSL certificates
#
# Usage: ./scripts/foreman-backup.sh
#

set -euo pipefail

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="${HOME}/foreman-backups/${TIMESTAMP}"
PI_HOST="pi.ra-home.co.uk"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if we can reach Pi
if ! ssh -o ConnectTimeout=5 "${PI_HOST}" "echo 'Connection OK'" &>/dev/null; then
    log_error "Cannot SSH to ${PI_HOST}. Please check connectivity."
    exit 1
fi

log_info "Creating backup directory: ${BACKUP_DIR}"
mkdir -p "${BACKUP_DIR}"

# 1. Backup PostgreSQL database
log_info "Backing up PostgreSQL database..."
ssh "${PI_HOST}" "sudo -u postgres pg_dump foreman | gzip" > "${BACKUP_DIR}/foreman_database.sql.gz"

if [ -f "${BACKUP_DIR}/foreman_database.sql.gz" ]; then
    SIZE=$(du -h "${BACKUP_DIR}/foreman_database.sql.gz" | cut -f1)
    log_info "Database backup completed: ${SIZE}"
else
    log_error "Database backup failed!"
    exit 1
fi

# 2. Backup Foreman configuration
log_info "Backing up Foreman configuration..."
ssh "${PI_HOST}" "sudo tar -czf - /etc/foreman /etc/foreman-proxy 2>/dev/null" > "${BACKUP_DIR}/foreman_config.tar.gz" || true

if [ -f "${BACKUP_DIR}/foreman_config.tar.gz" ]; then
    SIZE=$(du -h "${BACKUP_DIR}/foreman_config.tar.gz" | cut -f1)
    log_info "Configuration backup completed: ${SIZE}"
fi

# 3. Backup SSL certificates (system)
log_info "Backing up SSL certificates..."
ssh "${PI_HOST}" "sudo tar -czf - /etc/pki/tls/certs/foreman* /etc/pki/tls/private/foreman* 2>/dev/null" > "${BACKUP_DIR}/ssl_certs.tar.gz" || true

if [ -f "${BACKUP_DIR}/ssl_certs.tar.gz" ]; then
    SIZE=$(du -h "${BACKUP_DIR}/ssl_certs.tar.gz" | cut -f1)
    log_info "SSL certificates backup completed: ${SIZE}"
fi

# 4. Backup Puppet SSL certificates
log_info "Backing up Puppet SSL certificates..."
ssh "${PI_HOST}" "sudo tar -czf - /etc/puppetlabs/puppet/ssl 2>/dev/null" > "${BACKUP_DIR}/puppet_ssl.tar.gz" || true

if [ -f "${BACKUP_DIR}/puppet_ssl.tar.gz" ]; then
    SIZE=$(du -h "${BACKUP_DIR}/puppet_ssl.tar.gz" | cut -f1)
    log_info "Puppet SSL backup completed: ${SIZE}"
fi

# 5. Backup Foreman data directory
log_info "Backing up Foreman data directory..."
ssh "${PI_HOST}" "sudo tar -czf - /var/lib/foreman 2>/dev/null" > "${BACKUP_DIR}/foreman_data.tar.gz" || true

if [ -f "${BACKUP_DIR}/foreman_data.tar.gz" ]; then
    SIZE=$(du -h "${BACKUP_DIR}/foreman_data.tar.gz" | cut -f1)
    log_info "Foreman data backup completed: ${SIZE}"
fi

# 6. Export current Foreman settings (for reference)
log_info "Exporting Foreman settings..."
ssh "${PI_HOST}" "sudo foreman-rake db:seed:dump SEED=settings 2>/dev/null" > "${BACKUP_DIR}/foreman_settings.yaml" || {
    log_warn "Could not export Foreman settings (this is optional)"
}

# Create a manifest file
log_info "Creating backup manifest..."
cat > "${BACKUP_DIR}/MANIFEST.txt" << EOF
Foreman Backup Manifest
=======================
Date: $(date)
Source: ${PI_HOST}
Backup Directory: ${BACKUP_DIR}

Files:
------
EOF

for file in "${BACKUP_DIR}"/*; do
    if [ -f "$file" ]; then
        filename=$(basename "$file")
        filesize=$(du -h "$file" | cut -f1)
        echo "  - ${filename} (${filesize})" >> "${BACKUP_DIR}/MANIFEST.txt"
    fi
done

# Show summary
echo ""
log_info "========================================="
log_info "Backup completed successfully!"
log_info "========================================="
log_info "Backup location: ${BACKUP_DIR}"
log_info ""
log_info "Contents:"
cat "${BACKUP_DIR}/MANIFEST.txt"
echo ""

# Create a symlink to latest backup
ln -sfn "${BACKUP_DIR}" "${HOME}/foreman-backups/latest"
log_info "Latest backup symlink: ${HOME}/foreman-backups/latest"

# Verification
echo ""
log_info "Verification:"
if gunzip -t "${BACKUP_DIR}/foreman_database.sql.gz" 2>/dev/null; then
    log_info "✓ Database backup is valid"
else
    log_error "✗ Database backup is corrupted!"
    exit 1
fi

TOTAL_SIZE=$(du -sh "${BACKUP_DIR}" | cut -f1)
log_info "Total backup size: ${TOTAL_SIZE}"

echo ""
log_info "Next steps:"
echo "  1. Review backup contents in: ${BACKUP_DIR}"
echo "  2. Test database restore (optional):"
echo "     gunzip -c ${BACKUP_DIR}/foreman_database.sql.gz | head -100"
echo "  3. Proceed with migration following MIGRATION-FOREMAN.md"
