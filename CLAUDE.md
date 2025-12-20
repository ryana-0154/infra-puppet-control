# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

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

## Testing Patterns

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
- rspec-puppet unit tests (Puppet 7 and 8)
- bundler-audit security scan

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

### Auto-Promotion Process

When a PR is merged to `main`:
1. GitHub Actions automatically creates (or updates) a PR from `main` to `production`
2. The PR includes a deployment checklist and commit summary
3. Team reviews and approves the production PR
4. Once merged, r10k deploys changes to Puppet servers

This ensures all changes are reviewed twice: once for code quality, once for production readiness.
