#!/bin/bash
# Run all GitHub Actions CI checks locally
# This mirrors the checks in .github/workflows/ci.yml

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Track failures
FAILED_CHECKS=()

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

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

run_check() {
    local name="$1"
    local cmd="$2"

    echo -e "\n${YELLOW}Running: $name${NC}"
    echo "Command: $cmd"
    echo "---"

    if eval "$cmd"; then
        print_success "$name passed"
        return 0
    else
        print_failure "$name failed"
        FAILED_CHECKS+=("$name")
        return 1
    fi
}

# Change to repo root
SCRIPT_DIR="${BASH_SOURCE[0]%/*}"
cd "$SCRIPT_DIR/.."
REPO_ROOT=$(pwd)

print_header "Puppet Control Repo - Local CI Runner"

echo "Repository: $REPO_ROOT"
echo "Ruby version: $(ruby --version 2>/dev/null || echo 'not found')"
echo "Bundler version: $(bundle --version 2>/dev/null || echo 'not found')"

# Check if bundle is installed
if ! command -v bundle &> /dev/null; then
    echo -e "${RED}Error: Bundler not found. Please install with: gem install bundler${NC}"
    exit 1
fi

# Check if dependencies are installed
if [ ! -f "Gemfile.lock" ]; then
    print_warning "Gemfile.lock not found. Running bundle install..."
    bundle install
fi

print_header "Lint Checks"

# Puppet Lint
run_check "Puppet Lint" "bundle exec rake lint" || true

# Puppet Syntax
run_check "Puppet Syntax" "bundle exec rake syntax" || true

# RuboCop - use --fail-level convention to ignore internal cop errors
run_check "RuboCop" "bundle exec rubocop --fail-level convention 2>/dev/null" || true

# ERB Template Validation
run_check "ERB Template Validation" "bundle exec rake validate_templates" || true

# Test Coverage Check
run_check "Test Coverage Check" "bundle exec rake check_coverage" || true

print_header "Puppetfile Validation"

run_check "R10k Puppetfile Check" "bundle exec r10k puppetfile check" || true

print_header "Unit Tests"

# Install test fixtures if needed
if [ ! -d "spec/fixtures/modules" ]; then
    print_warning "Test fixtures not found. Running spec_prep..."
    bundle exec rake spec_prep
fi

run_check "RSpec Unit Tests" "bundle exec rake spec" || true

print_header "Security Scan"

run_check "Bundler Audit" "bundle exec bundler-audit check --update" || true

print_header "Acceptance Tests"

print_warning "Acceptance tests are currently a placeholder in CI - skipping locally"

print_header "Results Summary"

if [ ${#FAILED_CHECKS[@]} -eq 0 ]; then
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}  All checks passed!${NC}"
    echo -e "${GREEN}========================================${NC}"
    exit 0
else
    echo -e "${RED}========================================${NC}"
    echo -e "${RED}  ${#FAILED_CHECKS[@]} check(s) failed:${NC}"
    echo -e "${RED}========================================${NC}"
    for check in "${FAILED_CHECKS[@]}"; do
        echo -e "${RED}  - $check${NC}"
    done
    exit 1
fi
