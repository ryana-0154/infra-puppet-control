#!/bin/bash
# Update PiHole provisioning files from pihole-teleporter.zip backup
#
# Usage:
#   1. Download new backup from PiHole: Settings → Teleporter → Backup
#   2. Save pihole-teleporter.zip to repo root
#   3. Run this script: ./scripts/update-pihole-from-backup.sh
#   4. Review changes: git diff site-modules/profile/
#   5. Commit: git add site-modules/profile/ && git commit -m "Update PiHole configuration"

set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKUP_FILE="$REPO_ROOT/pihole-teleporter.zip"
TEMP_DIR="$REPO_ROOT/pihole-teleporter"
MODULE_DIR="$REPO_ROOT/site-modules/profile"

# Color output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}PiHole Backup Extractor${NC}"
echo "================================"

# Check if backup file exists
if [ ! -f "$BACKUP_FILE" ]; then
    echo -e "${RED}Error: pihole-teleporter.zip not found in repo root${NC}"
    echo "Please download a backup from PiHole and save it as pihole-teleporter.zip"
    exit 1
fi

# Clean up any previous extraction
if [ -d "$TEMP_DIR" ]; then
    echo -e "${YELLOW}Cleaning up previous extraction...${NC}"
    rm -rf "$TEMP_DIR"
fi

# Extract backup
echo "Extracting backup..."
unzip -q "$BACKUP_FILE" -d "$TEMP_DIR"

if [ ! -d "$TEMP_DIR/etc/pihole" ]; then
    echo -e "${RED}Error: Invalid backup structure (expected etc/pihole directory)${NC}"
    rm -rf "$TEMP_DIR"
    exit 1
fi

# Extract password hash for reference
echo ""
echo -e "${YELLOW}Password Hash (encrypt with eyaml):${NC}"
grep "pwhash =" "$TEMP_DIR/etc/pihole/pihole.toml" || echo "  (not found in pihole.toml)"
echo ""

# Process pihole.toml -> template
echo "Processing pihole.toml..."
TOML_TEMPLATE="$MODULE_DIR/templates/pihole/pihole.toml.erb"

# Create template directory if it doesn't exist
mkdir -p "$(dirname "$TOML_TEMPLATE")"

# Copy and parameterize password hash
sed 's/pwhash = ".*"/pwhash = "<%= @pihole_password_hash %>"/' \
    "$TEMP_DIR/etc/pihole/pihole.toml" > "$TOML_TEMPLATE"

echo -e "  ${GREEN}✓${NC} Updated $TOML_TEMPLATE"

# Copy gravity.db
echo "Copying gravity.db..."
GRAVITY_DB="$MODULE_DIR/files/pihole/gravity.db"
mkdir -p "$(dirname "$GRAVITY_DB")"
cp "$TEMP_DIR/etc/pihole/gravity.db" "$GRAVITY_DB"
echo -e "  ${GREEN}✓${NC} Updated $GRAVITY_DB"

# Copy custom hosts
echo "Copying custom hosts..."
CUSTOM_HOSTS="$MODULE_DIR/files/pihole/custom_hosts"
if [ -f "$TEMP_DIR/etc/hosts" ]; then
    cp "$TEMP_DIR/etc/hosts" "$CUSTOM_HOSTS"
    echo -e "  ${GREEN}✓${NC} Updated $CUSTOM_HOSTS"
else
    echo -e "  ${YELLOW}⚠${NC} No custom hosts file found in backup"
fi

# Clean up
echo "Cleaning up..."
rm -rf "$TEMP_DIR"

echo ""
echo -e "${GREEN}Success!${NC} PiHole configuration files have been updated."
echo ""
echo "Next steps:"
echo "  1. Review changes: git diff site-modules/profile/"
echo "  2. If password changed, update encrypted hash in Hiera:"
echo "     eyaml encrypt -s 'YOUR_NEW_PASSWORD_HASH'"
echo "  3. Commit changes:"
echo "     git add site-modules/profile/"
echo "     git commit -m \"Update PiHole configuration\""
echo "  4. Apply configuration:"
echo "     puppet agent -t"
echo ""
