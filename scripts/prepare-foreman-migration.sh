#!/usr/bin/env bash
#
# prepare-foreman-migration.sh - Prepare configuration for Foreman migration
#
# This script helps prepare the new foreman.ra-home.co.uk configuration by:
# 1. Copying encrypted passwords from pi.ra-home.co.uk.yaml
# 2. Generating new OAuth credentials
# 3. Updating the configuration file
#
# Usage: ./scripts/prepare-foreman-migration.sh
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
PI_CONFIG="${REPO_ROOT}/data/nodes/pi.ra-home.co.uk.yaml"
FOREMAN_CONFIG="${REPO_ROOT}/data/nodes/foreman.ra-home.co.uk.yaml"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
if [ ! -f "${PI_CONFIG}" ]; then
    log_error "Pi configuration not found: ${PI_CONFIG}"
    exit 1
fi

if [ ! -f "${FOREMAN_CONFIG}" ]; then
    log_error "Foreman configuration not found: ${FOREMAN_CONFIG}"
    exit 1
fi

if ! command -v eyaml &> /dev/null; then
    log_error "eyaml command not found. Please install: gem install hiera-eyaml"
    exit 1
fi

if ! command -v uuidgen &> /dev/null; then
    log_error "uuidgen command not found. Please install uuid-runtime package."
    exit 1
fi

log_info "========================================="
log_info "Foreman Migration Configuration Prep"
log_info "========================================="
echo ""

# Extract encrypted values from Pi config
log_info "Step 1: Extracting encrypted values from Pi configuration..."

DB_PASSWORD=$(grep -A 1 'profile::postgresql::database_users:' "${PI_CONFIG}" | grep 'password:' | awk '{print $2}' | tr -d "'")
ADMIN_PASSWORD=$(grep 'profile::foreman::admin_password:' "${PI_CONFIG}" | awk '{print $2}' | tr -d "'")

if [[ ! "${DB_PASSWORD}" =~ ^ENC\[PKCS7 ]]; then
    log_error "Could not extract database password from Pi config"
    exit 1
fi

if [[ ! "${ADMIN_PASSWORD}" =~ ^ENC\[PKCS7 ]]; then
    log_error "Could not extract admin password from Pi config"
    exit 1
fi

log_info "✓ Extracted database password"
log_info "✓ Extracted admin password"
echo ""

# Generate new OAuth credentials
log_info "Step 2: Generating new OAuth credentials..."

OAUTH_KEY=$(uuidgen | eyaml encrypt -s --stdin 2>/dev/null | grep 'ENC\[' | tr -d ' ')
OAUTH_SECRET=$(uuidgen | eyaml encrypt -s --stdin 2>/dev/null | grep 'ENC\[' | tr -d ' ')

if [[ ! "${OAUTH_KEY}" =~ ^ENC\[PKCS7 ]]; then
    log_error "Failed to generate OAuth key"
    exit 1
fi

if [[ ! "${OAUTH_SECRET}" =~ ^ENC\[PKCS7 ]]; then
    log_error "Failed to generate OAuth secret"
    exit 1
fi

log_info "✓ Generated OAuth consumer key"
log_info "✓ Generated OAuth consumer secret"
echo ""

# Create backup of current config
BACKUP_FILE="${FOREMAN_CONFIG}.backup.$(date +%Y%m%d_%H%M%S)"
cp "${FOREMAN_CONFIG}" "${BACKUP_FILE}"
log_info "Created backup: ${BACKUP_FILE}"
echo ""

# Update configuration file
log_info "Step 3: Updating foreman.ra-home.co.uk configuration..."

# Use a temporary file for sed operations
TMP_FILE=$(mktemp)
cp "${FOREMAN_CONFIG}" "${TMP_FILE}"

# Replace database password (in database_users section)
sed -i "s|password: 'COPY_ENCRYPTED_VALUE_FROM_PI_CONFIG'|password: '${DB_PASSWORD}'|" "${TMP_FILE}"

# Replace admin password
sed -i "s|profile::foreman::admin_password: 'COPY_ENCRYPTED_VALUE_FROM_PI_CONFIG'|profile::foreman::admin_password: '${ADMIN_PASSWORD}'|" "${TMP_FILE}"

# Replace db_password (should match database password)
sed -i "s|profile::foreman::db_password: 'COPY_ENCRYPTED_VALUE_FROM_PI_CONFIG'|profile::foreman::db_password: '${DB_PASSWORD}'|" "${TMP_FILE}"

# Replace OAuth credentials
sed -i "s|profile::foreman_proxy::oauth_consumer_key: 'GENERATE_NEW_ENCRYPTED_UUID'|profile::foreman_proxy::oauth_consumer_key: '${OAUTH_KEY}'|" "${TMP_FILE}"
sed -i "s|profile::foreman_proxy::oauth_consumer_secret: 'GENERATE_NEW_ENCRYPTED_UUID'|profile::foreman_proxy::oauth_consumer_secret: '${OAUTH_SECRET}'|" "${TMP_FILE}"

# Update migration date
sed -i "s|# Migrated from pi.ra-home.co.uk on <DATE>|# Migrated from pi.ra-home.co.uk on $(date +%Y-%m-%d)|" "${TMP_FILE}"

# Validate YAML syntax
if ruby -ryaml -e "YAML.load_file('${TMP_FILE}')" &>/dev/null; then
    log_info "✓ YAML syntax validated"
    mv "${TMP_FILE}" "${FOREMAN_CONFIG}"
else
    log_error "Generated configuration has invalid YAML syntax!"
    log_error "Temporary file preserved at: ${TMP_FILE}"
    log_error "Original backup at: ${BACKUP_FILE}"
    exit 1
fi

log_info "✓ Configuration updated successfully"
echo ""

# Show what was done
log_info "========================================="
log_info "Configuration Summary"
log_info "========================================="
echo ""
echo "Updated configuration file: ${FOREMAN_CONFIG}"
echo ""
echo "Changes made:"
echo "  ✓ Database password: Copied from Pi config"
echo "  ✓ Admin password: Copied from Pi config"
echo "  ✓ OAuth consumer key: Generated new encrypted UUID"
echo "  ✓ OAuth consumer secret: Generated new encrypted UUID"
echo "  ✓ Migration date: $(date +%Y-%m-%d)"
echo ""

log_info "Next steps:"
echo ""
echo "1. Review the updated configuration:"
echo "   eyaml decrypt -f ${FOREMAN_CONFIG}"
echo ""
echo "2. Verify YAML syntax:"
echo "   ruby -ryaml -e \"YAML.load_file('${FOREMAN_CONFIG}')\""
echo ""
echo "3. Update manifests/site.pp to add the new node:"
echo "   node 'foreman.ra-home.co.uk' {"
echo "     include role::foreman"
echo "   }"
echo ""
echo "4. Commit changes:"
echo "   git add data/nodes/foreman.ra-home.co.uk.yaml manifests/site.pp"
echo "   git commit -m 'feat: add foreman.ra-home.co.uk node for migration'"
echo ""
echo "5. Continue with migration following MIGRATION-FOREMAN.md"
echo ""

log_warn "IMPORTANT: Keep backup file until migration is complete!"
log_warn "Backup location: ${BACKUP_FILE}"
