# Puppet Control Repository

This repository contains the Puppet code and data for infrastructure management.

## Structure

```
├── data/                    # Hiera data
│   ├── common.yaml         # Common settings for all nodes
│   ├── nodes/              # Per-node data
│   └── os/                 # OS-specific data
├── manifests/              # Main manifests
│   └── site.pp            # Node classification
├── site-modules/           # Site-specific modules
│   ├── profile/           # Technology-specific profiles
│   └── role/              # Business-specific roles
├── modules/               # Forge modules (managed by r10k)
├── Puppetfile             # Module dependencies
├── hiera.yaml             # Hiera hierarchy configuration
└── environment.conf       # Environment configuration
```

## Getting Started

### Prerequisites

- Ruby 3.0+
- Bundler
- Python 3 (for pre-commit)

### Setup

```bash
# Install dependencies
bundle install

# Install pre-commit hooks
./scripts/install-hooks.sh

# Deploy modules
bundle exec r10k puppetfile install
```

## Development

### Running Tests

```bash
# Run all tests (lint + unit tests)
bundle exec rake test

# Run only linting
bundle exec rake lint_all

# Run only unit tests
bundle exec rake spec

# Run a specific test file
bundle exec rspec site-modules/profile/spec/classes/base_spec.rb
```

### Linting

```bash
# Puppet lint
bundle exec puppet-lint site-modules/

# Ruby lint
bundle exec rubocop

# All linting
bundle exec rake lint_all
```

### Pre-commit Hooks

Pre-commit hooks run automatically on `git commit`. To run manually:

```bash
pre-commit run --all-files
```

## Roles and Profiles

This repository follows the [roles and profiles](https://puppet.com/docs/pe/latest/the_roles_and_profiles_method.html) pattern:

- **Roles** are business-specific and define what a node is (e.g., `role::webserver`)
- **Profiles** are technology-specific and define how to configure something (e.g., `profile::webserver`)

## Branch Protection

The `main` branch is protected:
- Direct pushes are not allowed
- Pull requests require passing CI checks
- All linting and tests must pass before merge

## CI/CD

GitHub Actions runs on all pull requests and pushes to main:
- Puppet lint and syntax validation
- RuboCop style checking
- Unit tests with rspec-puppet (Puppet 7 and 8)
- Security scanning with bundler-audit

## Dependency Management

This repository uses [Renovate Bot](https://renovatebot.com/) to automatically keep dependencies up to date:

- **Docker images** in monitoring stack (Prometheus, Grafana, etc.)
- **Puppet modules** from Puppet Forge
- **Ruby gems** in Gemfile

Renovate creates PRs every Monday morning with grouped updates. Security updates are created immediately when detected.

See [docs/renovate.md](docs/renovate.md) for full documentation.
