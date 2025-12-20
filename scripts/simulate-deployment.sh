#!/bin/bash
# Simulate a deployment by compiling catalogs for test nodes
# This catches issues that unit tests might miss:
# - Missing module dependencies
# - Invalid class parameters
# - Resource type errors
# - Catalog compilation failures

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_header() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}========================================${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_failure() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}→ $1${NC}"
}

# Change to repo root
SCRIPT_DIR="${BASH_SOURCE[0]%/*}"
cd "$SCRIPT_DIR/.."
REPO_ROOT=$(pwd)

print_header "Deployment Simulation"
echo "Repository: $REPO_ROOT"
echo "Puppet version: $(puppet --version 2>/dev/null || echo 'not found')"

# Check if puppet is installed
if ! command -v puppet &> /dev/null; then
    print_failure "Puppet not found. Install with: gem install puppet"
    exit 1
fi

# Deploy modules
print_header "Step 1: Deploy Modules"
print_info "Deploying modules from Puppetfile..."

if ! bundle exec r10k puppetfile install --verbose; then
    print_failure "Failed to deploy modules from Puppetfile"
    exit 1
fi

print_success "Modules deployed successfully"

# Create a temporary directory for test manifests
TEST_DIR=$(mktemp -d)
trap "rm -rf $TEST_DIR" EXIT

print_header "Step 2: Test Catalog Compilation"

# Find all profiles
PROFILES=$(find site-modules/profile/manifests -name '*.pp' -not -name 'init.pp' -type f)

FAILED_PROFILES=()
PASSED_PROFILES=()

for profile_file in $PROFILES; do
    # Extract profile name from file path
    # site-modules/profile/manifests/base.pp -> profile::base
    # site-modules/profile/manifests/foo/bar.pp -> profile::foo::bar
    profile_name=$(echo "$profile_file" | \
        sed 's|site-modules/profile/manifests/||' | \
        sed 's|\.pp$||' | \
        tr '/' '::')

    profile_class="profile::${profile_name}"

    print_info "Testing ${profile_class}..."

    # Create a test manifest
    cat > "$TEST_DIR/test.pp" <<EOF
# Test manifest for ${profile_class}
node 'test.example.com' {
  include ${profile_class}
}
EOF

    # Try to compile the catalog
    if puppet apply --noop \
        --certname=test.example.com \
        --modulepath=modules:site-modules \
        --hiera_config=hiera.yaml \
        "$TEST_DIR/test.pp" > "$TEST_DIR/output.log" 2>&1; then
        print_success "${profile_class} - catalog compiled successfully"
        PASSED_PROFILES+=("$profile_class")
    else
        print_failure "${profile_class} - catalog compilation failed"
        echo "Error output:"
        cat "$TEST_DIR/output.log" | grep -A 5 "Error:"
        echo ""
        FAILED_PROFILES+=("$profile_class")
    fi
done

# Test roles too
print_header "Step 3: Test Roles"

ROLES=$(find site-modules/role/manifests -name '*.pp' -not -name 'init.pp' -type f)

for role_file in $ROLES; do
    role_name=$(echo "$role_file" | \
        sed 's|site-modules/role/manifests/||' | \
        sed 's|\.pp$||' | \
        tr '/' '::')

    role_class="role::${role_name}"

    print_info "Testing ${role_class}..."

    cat > "$TEST_DIR/test.pp" <<EOF
# Test manifest for ${role_class}
node 'test.example.com' {
  include ${role_class}
}
EOF

    if puppet apply --noop \
        --certname=test.example.com \
        --modulepath=modules:site-modules \
        --hiera_config=hiera.yaml \
        "$TEST_DIR/test.pp" > "$TEST_DIR/output.log" 2>&1; then
        print_success "${role_class} - catalog compiled successfully"
        PASSED_PROFILES+=("$role_class")
    else
        print_failure "${role_class} - catalog compilation failed"
        echo "Error output:"
        cat "$TEST_DIR/output.log" | grep -A 5 "Error:"
        echo ""
        FAILED_PROFILES+=("$role_class")
    fi
done

# Summary
print_header "Deployment Simulation Summary"

echo "Total classes tested: $((${#PASSED_PROFILES[@]} + ${#FAILED_PROFILES[@]}))"
echo "Passed: ${#PASSED_PROFILES[@]}"
echo "Failed: ${#FAILED_PROFILES[@]}"
echo ""

if [ ${#FAILED_PROFILES[@]} -eq 0 ]; then
    print_success "All catalogs compiled successfully!"
    echo ""
    echo "This deployment simulation verifies that:"
    echo "  ✓ All required modules are available"
    echo "  ✓ No missing dependencies"
    echo "  ✓ All class parameters are valid"
    echo "  ✓ Catalogs can be compiled without errors"
    exit 0
else
    print_failure "Deployment simulation found issues:"
    for failed in "${FAILED_PROFILES[@]}"; do
        echo "  - $failed"
    done
    echo ""
    echo "Fix these issues before deploying to production!"
    exit 1
fi
