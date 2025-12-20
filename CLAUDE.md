# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

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

## CI Requirements

All PRs require passing:
- Puppet lint and syntax checks
- RuboCop style checks
- rspec-puppet unit tests (Puppet 7 and 8)
- bundler-audit security scan
