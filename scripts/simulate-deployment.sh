#!/bin/bash
# Simulate a deployment by compiling catalogs for test nodes
# This catches issues that unit tests might miss:
# - Missing module dependencies
# - Invalid class parameters
# - Resource type errors
# - Catalog compilation failures
#
# Requirements:
# - puppet gem installed (gem install puppet)
# - hiera-eyaml gem installed (gem install hiera-eyaml)
# - r10k gem installed (bundle exec r10k or gem install r10k)

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

# Check if puppet is installed
if ! command -v puppet &> /dev/null; then
    print_failure "Puppet not found. Install with: gem install puppet"
    exit 1
fi

echo "Puppet version: $(puppet --version)"

# Check if hiera-eyaml is installed
if ! gem list -i hiera-eyaml &> /dev/null; then
    print_failure "hiera-eyaml gem not found"
    echo "This is required for Hiera lookups during catalog compilation."
    echo "Install with: gem install hiera-eyaml"
    exit 1
fi

echo "hiera-eyaml: installed"

# Check if r10k is available (prefer bundler over global)
if command -v bundle &> /dev/null && bundle exec r10k help &> /dev/null 2>&1; then
    echo "r10k: available (via bundler)"
    R10K_AVAILABLE="bundler"
elif command -v r10k &> /dev/null; then
    echo "r10k: available (global)"
    R10K_AVAILABLE="global"
else
    print_failure "r10k not found"
    echo "Install with: gem install r10k"
    echo "Or use via bundler: bundle install"
    exit 1
fi

# Deploy modules
print_header "Step 1: Deploy Modules"
print_info "Deploying modules from Puppetfile..."

# Use the r10k command based on what was detected
if [ "$R10K_AVAILABLE" = "bundler" ]; then
    R10K_CMD="bundle exec r10k"
else
    R10K_CMD="r10k"
fi

if ! $R10K_CMD puppetfile install --verbose; then
    print_failure "Failed to deploy modules from Puppetfile"
    exit 1
fi

print_success "Modules deployed successfully"

# Validate class includes
print_header "Step 2: Validate Class Includes"
print_info "Checking that all included classes actually exist..."

if [ -f "scripts/validate-class-includes.rb" ]; then
    if ruby scripts/validate-class-includes.rb; then
        print_success "All included classes are defined"
    else
        print_failure "Class validation failed"
        echo "This catches issues like including classes that don't exist in their modules."
        exit 1
    fi
else
    print_info "Skipping class validation (validate-class-includes.rb not found)"
fi

# Create a temporary directory for test manifests
TEST_DIR=$(mktemp -d)
trap "rm -rf $TEST_DIR" EXIT

print_header "Step 3: Test Catalog Compilation"

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
print_header "Step 4: Test Roles"

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

# Test common profile combinations
print_header "Step 5: Test Profile Combinations"
print_info "Testing common profile combinations to catch resource contention..."

FAILED_COMBINATIONS=()
PASSED_COMBINATIONS=()

# Test combination: Base + Monitoring + OTEL
print_info "Testing: Base + Monitoring + OTEL..."
cat > "$TEST_DIR/combo_test.pp" <<'EOF'
node 'test-combo.example.com' {
  class { 'profile::base':
    manage_otel_collector => true,
  }
  include profile::monitoring
}
EOF

if puppet apply --noop \
    --certname=test-combo.example.com \
    --modulepath=modules:site-modules \
    --hiera_config=hiera.yaml \
    "$TEST_DIR/combo_test.pp" > "$TEST_DIR/combo_output.log" 2>&1; then
    print_success "Base + Monitoring + OTEL - no resource conflicts"
    PASSED_COMBINATIONS+=("Base + Monitoring + OTEL")
else
    print_failure "Base + Monitoring + OTEL - resource conflicts detected"
    echo "Error output:"
    cat "$TEST_DIR/combo_output.log" | grep -A 5 "Error:\|Duplicate declaration:"
    echo ""
    FAILED_COMBINATIONS+=("Base + Monitoring + OTEL")
fi

# Test combination: Base + Monitoring (no OTEL)
print_info "Testing: Base + Monitoring (no OTEL)..."
cat > "$TEST_DIR/combo_test.pp" <<'EOF'
node 'test-combo.example.com' {
  class { 'profile::base':
    manage_otel_collector => false,
  }
  include profile::monitoring
}
EOF

if puppet apply --noop \
    --certname=test-combo.example.com \
    --modulepath=modules:site-modules \
    --hiera_config=hiera.yaml \
    "$TEST_DIR/combo_test.pp" > "$TEST_DIR/combo_output.log" 2>&1; then
    print_success "Base + Monitoring (no OTEL) - no resource conflicts"
    PASSED_COMBINATIONS+=("Base + Monitoring (no OTEL)")
else
    print_failure "Base + Monitoring (no OTEL) - resource conflicts detected"
    echo "Error output:"
    cat "$TEST_DIR/combo_output.log" | grep -A 5 "Error:\|Duplicate declaration:"
    echo ""
    FAILED_COMBINATIONS+=("Base + Monitoring (no OTEL)")
fi

# Test combination: Monitoring + OTEL
print_info "Testing: Monitoring + OTEL..."
cat > "$TEST_DIR/combo_test.pp" <<'EOF'
node 'test-combo.example.com' {
  include profile::monitoring
  include profile::otel_collector
}
EOF

if puppet apply --noop \
    --certname=test-combo.example.com \
    --modulepath=modules:site-modules \
    --hiera_config=hiera.yaml \
    "$TEST_DIR/combo_test.pp" > "$TEST_DIR/combo_output.log" 2>&1; then
    print_success "Monitoring + OTEL - no resource conflicts"
    PASSED_COMBINATIONS+=("Monitoring + OTEL")
else
    print_failure "Monitoring + OTEL - resource conflicts detected"
    echo "Error output:"
    cat "$TEST_DIR/combo_output.log" | grep -A 5 "Error:\|Duplicate declaration:"
    echo ""
    FAILED_COMBINATIONS+=("Monitoring + OTEL")
fi

# Test combination: Base + Dotfiles
print_info "Testing: Base + Dotfiles..."
cat > "$TEST_DIR/combo_test.pp" <<'EOF'
node 'test-combo.example.com' {
  include profile::base
  include profile::dotfiles
}
EOF

if puppet apply --noop \
    --certname=test-combo.example.com \
    --modulepath=modules:site-modules \
    --hiera_config=hiera.yaml \
    "$TEST_DIR/combo_test.pp" > "$TEST_DIR/combo_output.log" 2>&1; then
    print_success "Base + Dotfiles - no resource conflicts"
    PASSED_COMBINATIONS+=("Base + Dotfiles")
else
    print_failure "Base + Dotfiles - resource conflicts detected"
    echo "Error output:"
    cat "$TEST_DIR/combo_output.log" | grep -A 5 "Error:\|Duplicate declaration:"
    echo ""
    FAILED_COMBINATIONS+=("Base + Dotfiles")
fi

# Summary
print_header "Deployment Simulation Summary"

echo "Individual classes tested: $((${#PASSED_PROFILES[@]} + ${#FAILED_PROFILES[@]}))"
echo "  Passed: ${#PASSED_PROFILES[@]}"
echo "  Failed: ${#FAILED_PROFILES[@]}"
echo ""
echo "Profile combinations tested: $((${#PASSED_COMBINATIONS[@]} + ${#FAILED_COMBINATIONS[@]}))"
echo "  Passed: ${#PASSED_COMBINATIONS[@]}"
echo "  Failed: ${#FAILED_COMBINATIONS[@]}"
echo ""

TOTAL_FAILED=$((${#FAILED_PROFILES[@]} + ${#FAILED_COMBINATIONS[@]}))

if [ $TOTAL_FAILED -eq 0 ]; then
    print_success "All catalogs compiled successfully!"
    echo ""
    echo "This deployment simulation verifies that:"
    echo "  ✓ All required modules are available"
    echo "  ✓ No missing dependencies"
    echo "  ✓ All class parameters are valid"
    echo "  ✓ Catalogs can be compiled without errors"
    echo "  ✓ Common profile combinations work without resource conflicts"
    exit 0
else
    print_failure "Deployment simulation found issues:"

    if [ ${#FAILED_PROFILES[@]} -gt 0 ]; then
        echo ""
        echo "Failed individual classes:"
        for failed in "${FAILED_PROFILES[@]}"; do
            echo "  - $failed"
        done
    fi

    if [ ${#FAILED_COMBINATIONS[@]} -gt 0 ]; then
        echo ""
        echo "Failed profile combinations (resource conflicts):"
        for failed in "${FAILED_COMBINATIONS[@]}"; do
            echo "  - $failed"
        done
    fi

    echo ""
    echo "Fix these issues before deploying to production!"
    exit 1
fi
