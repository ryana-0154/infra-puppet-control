# Renovate Bot Configuration

This repository is configured with [Renovate Bot](https://renovatebot.com/) to automatically keep dependencies up to date.

## What Renovate Monitors

Renovate automatically scans for and updates:

### 🐳 Docker Images
- **Monitoring stack images** in `site-modules/profile/manifests/monitoring.pp`
- **Hiera overrides** in `data/**/*.yaml` files
- **Templates** in `site-modules/profile/templates/monitoring/docker-compose.yaml.erb`

Monitored images:
- `prom/prometheus`
- `grafana/grafana`
- `grafana/loki`
- `grafana/promtail`
- `ekofr/pihole-exporter`
- `prom/blackbox-exporter`
- `quay.io/prometheus/node-exporter`
- `wgportal/wg-portal`

### 🎭 Puppet Modules
- All modules defined in `Puppetfile`
- Follows semantic versioning for updates
- 3-day minimum age before updates are proposed

### 💎 Ruby Gems
- Dependencies in `Gemfile`
- Security updates are prioritized
- Development and testing gems included

## Update Schedule

- **Regular updates**: Monday mornings before 6am (Europe/London)
- **Security updates**: Immediate (at any time)
- **Vulnerability alerts**: Enabled with OSV database

## Update Grouping

Updates are intelligently grouped to reduce PR noise:
- **Docker images in monitoring**: Single PR for all monitoring stack updates
- **Puppet modules**: Single PR for all Forge module updates
- **Ruby dependencies**: Single PR for all gem updates
- **Security updates**: Separate high-priority PRs

## Pull Request Behavior

### Rate Limiting
- Maximum 3 concurrent PRs
- Maximum 2 PRs per hour
- Prevents overwhelming the repository

### PR Settings
- **Auto-merge**: Disabled (manual review required)
- **Labels**: `dependencies` (+ `security` for security updates)
- **Assignees**: `@ryana-0154`
- **Semantic commits**: Enabled with `chore(deps):` prefix

### Review Process
1. Renovate creates PR with update details
2. CI runs automatically (lint, tests, deployment simulation)
3. Manual review and approval required
4. Merge when ready

## Configuration Files

- **`renovate.json`**: Main configuration file
- **`.github/renovate.json`**: Alternative location (not used)

## Security Features

- **Vulnerability scanning**: OSV and GitHub advisories
- **Security updates**: High priority, immediate scheduling
- **Dependency validation**: Only updates from trusted sources
- **Minimum release age**: Prevents dependency confusion attacks

## Customization

To modify Renovate behavior, edit `renovate.json`:

### Disable Updates for Specific Dependencies
```json
{
  "packageRules": [
    {
      "matchPackageNames": ["specific-package"],
      "enabled": false
    }
  ]
}
```

### Change Update Schedule
```json
{
  "schedule": ["before 6am on Monday and Friday"]
}
```

### Enable Auto-merge for Patches
```json
{
  "packageRules": [
    {
      "matchUpdateTypes": ["patch"],
      "automerge": true
    }
  ]
}
```

## Monitoring

### PR Dashboard
View all Renovate PRs: [Repository Pull Requests](../../pulls?q=is:pr+author:app/renovate)

### Logs
Renovate logs are available in PR descriptions and the Renovate dashboard.

### Troubleshooting

**No PRs being created?**
- Check repository settings allow Renovate Bot
- Verify `renovate.json` syntax is valid
- Check rate limiting hasn't been exceeded

**Updates not detected?**
- Verify regex patterns in `renovate.json`
- Check file paths match `fileMatch` patterns
- Ensure version formats are supported

**PRs failing CI?**
- Review pre-commit hooks
- Check puppet-lint and syntax validation
- Verify test coverage requirements

## Best Practices

1. **Review security updates quickly** - These are scheduled immediately
2. **Test in non-production first** - Use the main→production branch workflow
3. **Group related updates** - Renovate does this automatically
4. **Monitor for breaking changes** - Check changelogs in PR descriptions
5. **Keep `renovate.json` updated** - As new dependencies are added

## Integration with CI/CD

Renovate PRs trigger the full CI pipeline:
- Puppet lint and syntax checks
- RuboCop style validation
- Test coverage verification
- Deployment simulation
- Security scanning

This ensures all updates are validated before merge.

## Support

For Renovate-specific issues:
- [Renovate Documentation](https://docs.renovatebot.com/)
- [GitHub Discussions](https://github.com/renovatebot/renovate/discussions)

For repository-specific issues, create an issue in this repository.
