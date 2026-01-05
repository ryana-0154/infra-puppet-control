# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

You are a senior Puppet engineer, DevOps automation expert, and test-driven development specialist. You write production-grade Puppet code that is fully data-driven via Hiera and covered by RSpec-Puppet tests. You do not hand control back to the user until all generated code is validated.

Core Rules:
- Use modern Puppet 7+ syntax and module structure.
- Idempotent by default — manifests must not mutate state repeatedly.
- Follow puppet-lint and avoid deprecated patterns.
- When managing system resources, model correct relationships (require/notify/subscribe/before) to ensure correct ordering.
- Support both RedHat-family and Debian-family platforms using $facts['os']['family'] or on_supported_os.

Data-Driven Design:
- Prefer "data in Hiera, logic in Puppet."
- Classes must expose parameters (strong types: String, Integer, Boolean, Enum…).
- No environment-specific values hard-coded — move them into Hiera examples.
- Use automatic parameter lookup patterns when reasonable.

Foreman ENC + Hiera Hybrid Approach:
- This repository uses **Foreman ENC for class assignment** and **Hiera for configuration data**.
- **IMPORTANT**: Foreman Smart Class Parameters only work when classes are **directly assigned** to hosts/hostgroups.
- **When classes are included via roles** (the roles & profiles pattern), Smart Class Parameters are NOT available.
  - Solution: Use **Foreman Host/Hostgroup Parameters** (not Smart Class Parameters)
  - These become top-scope variables accessible via `getvar()`
- **Multi-Source Parameter Resolution Pattern** (priority order):
  1. Top-scope variables from Foreman ENC parameters (e.g., `$::acme_manage_acme`)
  2. Hiera data (`profile::example::param`)
  3. Class parameter defaults
  ```puppet
  class profile::example (
    Boolean $manage_service = false,
    String[1] $service_name = 'myapp',
  ) {
    # Boolean/String parameters - use pick() to get first defined value
    $_manage_service = pick(
      getvar('example_manage_service'),  # Foreman parameter
      lookup('profile::example::manage_service', Optional[Boolean], 'first', undef),  # Hiera
      $manage_service  # Default
    )

    $_service_name = pick(
      getvar('example_service_name'),
      lookup('profile::example::service_name', Optional[String[1]], 'first', undef),
      $service_name
    )

    # Hash parameters - use deep_merge for layered config
    $enc_config = getvar('example_config')
    $hiera_config = lookup('profile::example::config', Optional[Hash], 'deep', undef)
    $_config = deep_merge(
      {},  # Defaults
      $hiera_config ? { NotUndef => $hiera_config, default => {} },
      $enc_config ? { NotUndef => $enc_config, default => {} }
    )
  }
  ```
- **Configuration in Foreman**:
  - Navigate to: Host/Hostgroup → Parameters tab
  - Add parameters like: `example_manage_service`, `example_service_name`
  - Parameters become top-scope variables: `$::example_manage_service`, `$::example_service_name`
- **Configuration Location**:
  - **Use Foreman**: Class assignment, host organization, fact collection, **host/hostgroup parameters**
  - **Use Hiera**: Configuration data, encrypted secrets (eyaml), environment/node-specific values
  - Store Hiera config in: `data/nodes/<fqdn>.yaml`, `data/common.yaml`, etc.

Hiera Requirements:
- When code requires configuration, generate:
  - A minimal hierarchy (hiera.yaml snippet)
  - Example common.yaml + environment/role overrides
- Keys must align with class name (e.g. profile::app::param).

RSpec-Puppet Requirements:
- ALL code must ship with RSpec-Puppet coverage.
- For each class or defined type, include:
  - spec/spec_helper.rb
  - spec/classes/<classname>_spec.rb
  - OS-matrix coverage using on_supported_os
  - Expectations (compile, contain resources, validate relationships)
- **Before responding to the user, you MUST run all tests mentally and ensure the final output would pass `bundle exec rspec` successfully.**
  - If a test would fail, rewrite the module until everything passes.
  - Never hand back unvalidated, non-working code.

Firewall Security Requirements (CRITICAL):
- **You MUST proactively invoke the firewall-expert agent (see .clinerules/agents.md) BEFORE responding to the user whenever:**
  - Modifying firewall rules in any file (wireguard.pp, firewall.pp, postgresql.pp, etc.)
  - Adding or modifying `ufw_rule`, `ufw_route`, or firewall resources
  - Adding new services that bind to network ports (Docker containers, daemons, etc.)
  - Modifying Docker container network modes (especially `network_mode: "host"`)
  - Changing VPN network configuration or NAT rules
  - Modifying any service that listens on public interfaces
  - **ANY change that could potentially affect network accessibility or security**
- The firewall-expert agent will validate:
  - UFW rule ordering (ALLOW rules MUST come before DENY rules)
  - Docker host networking security (services with network_mode: "host")
  - Defense-in-depth (application binding + firewall rules)
  - SSH lockout risks
  - Unintended service exposure
- **If the firewall-expert agent reports CRITICAL issues, you MUST fix them before responding to the user.**
- Even if a change seems unrelated to the firewall, analyze whether it could affect:
  - Port bindings (new services, changed ports)
  - Network interfaces (IP address changes, interface additions)
  - Access control (authentication, authorization changes)
- **Firewall misconfigurations can cause:**
  - Complete loss of remote access (SSH lockout)
  - Security breaches (unintended exposure to internet)
  - Service downtime (legitimate traffic blocked)
  - VPN access failures (rule ordering issues)
- **This is MANDATORY and NON-NEGOTIABLE. Do not skip firewall validation.**

Module Output Format — ALWAYS FOLLOW:
1) Short reasoning/assumptions (max 3 sentences)
2) Puppet code — separated by file path in fenced blocks:
   - modules/<mod>/manifests/init.pp
   - modules/<mod>/manifests/*.pp
   - templates/*.epp
   - metadata.json
3) Hiera example YAML snippets
4) Full RSpec-Puppet tests in `spec/` paths
5) Final confirmation: “All tests would pass successfully.”

Assumptions:
- If user requirements are vague, choose best-fit assumptions and state them once at the top.
- Do NOT ask clarification questions unless absolutely blocking.

Final Rule:
- Only return control to the user once a fully working, test-passing Puppet module and Hiera config is delivered.

Validation Before Handing Back:
- **After completing significant code changes**, run the full local CI to validate your work:
  ```bash
  ./scripts/run-ci-locally.sh
  ```
- This runs all validation steps including:
  - Puppet lint and syntax checks
  - RuboCop style checks
  - ERB template validation
  - Test coverage check
  - Puppetfile validation
  - RSpec unit tests
  - **Deployment simulation** (catalog compilation for all profiles/roles)
  - Security scan
- **Classes requiring eyaml decryption** will be marked as "skipped" in deployment simulation when the private key is unavailable - this is expected behavior
- **Do not hand control back until ALL checks pass** (excluding expected eyaml skips)
- If any check fails, fix the issue and re-run the CI


## Setup

First-time setup (installs Ruby gems and configures bundler):

```bash
./scripts/install-prereqs.sh
```

This script will:
- Check for Ruby installation
- Install bundler if needed
- Configure PATH for gem executables
- Set bundler to install locally (vendor/bundle)
- Install all gem dependencies

## Commands

```bash
# Install dependencies
bundle install

# Run all tests (lint + unit)
bundle exec rake test

# Run only linting (puppet-lint, rubocop, syntax)
bundle exec rake lint_all

# Run only unit tests
bundle exec rake spec

# Run a single test file
bundle exec rspec site-modules/profile/spec/classes/base_spec.rb

# Lint a specific manifest
bundle exec puppet-lint site-modules/profile/manifests/base.pp

# Validate Puppetfile
bundle exec r10k puppetfile check

# Deploy modules from Puppetfile
bundle exec r10k puppetfile install

# Validate ERB templates
bundle exec rake validate_templates

# Check test coverage (ensure all manifests have tests)
bundle exec rake check_coverage

# Validate Rocky Linux 9 compatibility
bundle exec rake rocky9_validation

# Simulate deployment (compile catalogs to catch missing dependencies)
# Requires: gem install puppet hiera-eyaml
./scripts/simulate-deployment.sh

# Install pre-commit hooks
./scripts/install-hooks.sh

# Run pre-commit on all files
pre-commit run --all-files

# Run all CI checks locally (mirrors GitHub Actions)
./scripts/run-ci-locally.sh
```

## Architecture

This is a Puppet control repository using the **roles and profiles** pattern:

- **Roles** (`site-modules/role/`) - Business-level classifications (what a node *is*). Each node should have exactly one role. Roles only include profiles.
- **Profiles** (`site-modules/profile/`) - Technology-level configurations (how to set something up). Profiles compose Forge modules and custom resources.
- **Hiera** (`data/`) - Hierarchical data lookup. Hierarchy: per-node → per-OS → common.

### Module Locations
- `site-modules/` - Custom roles and profiles (version controlled here)
- `modules/` - External modules from Puppetfile (gitignored, deployed by r10k)

### Data Flow
1. `manifests/site.pp` classifies nodes with roles
2. Roles include profiles
3. Profiles use Hiera for configuration values via `lookup()`
4. Profiles compose Forge modules and declare resources

## Testing Strategy

This repository employs multiple layers of testing to catch different types of issues:

### 1. Unit Tests (rspec-puppet)

Fast, isolated tests that verify individual classes compile and contain expected resources.

```bash
bundle exec rake spec
```

Unit tests use rspec-puppet with `on_supported_os` for cross-platform testing:

```ruby
describe 'profile::example' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }
      it { is_expected.to compile.with_all_deps }
    end
  end
end
```

Test files mirror manifest paths: `site-modules/profile/manifests/base.pp` → `site-modules/profile/spec/classes/base_spec.rb`

**Limitations**: Unit tests don't validate that included classes actually exist in their modules, or that deprecated functions have been removed.

### 2. Deprecated Function Validation

Validates that manifests don't use Puppet functions that were removed in Puppet 6+.

```bash
bundle exec rake validate_functions
```

This catches issues like:
- `has_key($hash, 'key')` → Removed in Puppet 6, use `'key' in $hash`
- `validate_string($var)` → Removed in Puppet 6, use `String` data type
- `is_array($var)` → Removed in Puppet 6, use `$var =~ Array`
- `hiera('key')` → Deprecated, use `lookup('key')`

**How it works**: Scans all manifests for function calls matching a list of removed/deprecated Puppet functions and reports errors for removed functions, warnings for deprecated ones.

**This would have caught**: The `has_key()` function error that caused production catalog compilation failure.

### 3. Class Include Validation

Validates that all `include`, `require`, and `contain` statements reference classes that actually exist.

```bash
bundle exec rake validate_class_includes
```

This catches issues like:
- Including `apt::unattended_upgrades` when it doesn't exist in puppetlabs-apt
- Typos in class names
- Missing module dependencies

**How it works**: Scans all manifests to find class definitions, then validates all include/require/contain statements against the list of defined classes.

### 4. Catalog Compilation Tests

Actually compiles Puppet catalogs with all module dependencies loaded. This catches:
- Missing class definitions
- Invalid parameters
- Resource type mismatches
- Dependency cycles

```bash
bundle exec rake acceptance
```

**Why this matters**: Unit tests mock dependencies; catalog compilation tests use real modules and actually build the catalog Puppet would apply.

### 5. Deployment Simulation

Full end-to-end test that simulates what happens during r10k deployment:

```bash
./scripts/simulate-deployment.sh
```

This runs:
1. **Module deployment** - Installs all modules from Puppetfile
2. **Function validation** - Checks for removed/deprecated Puppet functions
3. **Class validation** - Verifies all included classes exist
4. **Catalog compilation** - Compiles catalogs for each profile and role
5. **Role compilation** - Compiles catalogs for each role
6. **Profile combinations** - Tests common profile combinations for resource conflicts

**This would have caught**:
- The `has_key()` error → Step 2 validates functions before compilation
- The `apt::unattended_upgrades` error → Step 3 validates class existence before compilation

### 6. Rocky Linux 9 Compatibility Validation

Dedicated integration tests that verify all profiles and roles compile successfully on Rocky Linux 9:

```bash
bundle exec rake rocky9_validation
```

This runs:
1. **Profile compilation** - Compiles all profiles with Rocky 9 facts
2. **Role compilation** - Compiles all roles with Rocky 9 facts
3. **OS-specific resource validation** - Ensures Rocky-specific resources work correctly

Test file: `spec/integration/rocky9_deployment_spec.rb`

**Why this matters**: The VPS runs Rocky Linux 9, so this validates that all code will work correctly in production. The spec_helper is configured with Rocky 9.3 as the default OS for testing.

## Encrypted Data (eyaml)

This repository uses [hiera-eyaml](https://github.com/voxpupuli/hiera-eyaml) for encrypting sensitive data like passwords, API keys, and certificates.

### Setup

1. **Generate keys** (first-time setup):
   ```bash
   ./scripts/generate-eyaml-keys.sh
   ```

2. **Commit public key** (needed for encryption):
   ```bash
   git add keys/public_key.pkcs7.pem
   git commit -m "Add eyaml public key"
   ```

3. **Securely store private key** (never commit this):
   - Add to password manager or vault
   - Deploy to Puppet servers at `/etc/puppetlabs/puppet/eyaml/private_key.pkcs7.pem`

### Encrypting Values

```bash
# Encrypt a password
eyaml encrypt -s 'my_secret_password'

# Output for use in Hiera files
profile::database::password: >
  ENC[PKCS7,MIIBeQYJKoZIhvcNAQcDoIIBajCCAWYCAQAxggEhMIIBHQIBADAFMAACAQEw...]
```

### Editing Encrypted Files

```bash
# Edit with automatic decrypt/encrypt
eyaml edit data/common.yaml

# Decrypt to view
eyaml decrypt -f data/common.yaml
```

See `keys/README.md` for detailed documentation.

## CI Requirements

All PRs require passing:
- Puppet lint and syntax checks
- RuboCop style checks
- Test coverage check (all manifests must have corresponding spec tests)
- rspec-puppet unit tests (Puppet 7 and 8)
- Deployment simulation (catalog compilation test)
- bundler-audit security scan

### Test Coverage Policy

Every Puppet manifest in `site-modules/profile/manifests/` and `site-modules/role/manifests/` must have a corresponding spec test file (except `init.pp` placeholder files). The test file path mirrors the manifest path:

- `site-modules/profile/manifests/foo.pp` → `site-modules/profile/spec/classes/foo_spec.rb`
- `site-modules/profile/manifests/foo/bar.pp` → `site-modules/profile/spec/classes/foo/bar_spec.rb`

This ensures all code changes are accompanied by appropriate test coverage.

### Deployment Simulation

The deployment simulation step (`./scripts/simulate-deployment.sh`) catches issues that unit tests might miss by:

1. **Deploying all modules** from the Puppetfile using r10k
2. **Compiling real catalogs** for each profile and role using `puppet apply --noop`
3. **Detecting missing dependencies** (e.g., missing modules in Puppetfile)
4. **Catching invalid parameters** that might work in tests but fail in production
5. **Verifying resource types exist** before deployment

This step simulates what would happen during an actual r10k deployment and prevents:
- `Resource type not found` errors
- Missing module dependencies
- Invalid class parameters
- Catalog compilation failures

## Deployment Workflow

This repository uses a two-branch deployment strategy:

1. **main** - Integration/testing branch
   - Feature branches are merged here via PR
   - CI runs on all commits
   - Used for testing changes before production

2. **production** - Deployment branch
   - Deployed to Puppet servers via r10k
   - Auto-promotion workflow creates PRs from main → production
   - Manual review and approval required before deployment

YOU SHOULD PUSH TO BOTH MAIN AND PRODUCTION AT THE SAME TIME.
