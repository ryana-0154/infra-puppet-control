# Branch Protection Setup

Branch protection requires GitHub Pro for private repositories. Follow these manual steps to configure protection:

## Steps

1. Go to **Settings** → **Branches** in your GitHub repository
2. Under "Branch protection rules", click **Add rule**
3. Set "Branch name pattern" to `main`
4. Enable the following settings:

### Required Settings
- [x] **Require a pull request before merging**
  - [x] Require approvals (1)
  - [x] Dismiss stale pull request approvals when new commits are pushed
- [x] **Require status checks to pass before merging**
  - [x] Require branches to be up to date before merging
  - Add required status checks:
    - `All Checks Pass`
- [x] **Do not allow bypassing the above settings**

### Recommended Settings
- [x] **Require conversation resolution before merging**
- [ ] **Require signed commits** (optional)
- [x] **Do not allow force pushes**
- [x] **Do not allow deletions**

5. Click **Create** to save the rule

## Required CI Checks

The following CI jobs must pass before merging:

| Check Name | Description |
|------------|-------------|
| `All Checks Pass` | Aggregates all required checks |
| `Lint` | Puppet lint, syntax, and RuboCop |
| `Puppetfile Validation` | r10k Puppetfile check |
| `Unit Tests (Puppet 7.0)` | rspec-puppet on Puppet 7 |
| `Unit Tests (Puppet 8.0)` | rspec-puppet on Puppet 8 |
| `Security Scan` | bundler-audit security check |

## Alternative: Make Repository Public

If you make the repository public, you can use the GitHub API to set branch protection:

```bash
gh api repos/OWNER/REPO/branches/main/protection -X PUT \
  -H "Accept: application/vnd.github+json" \
  -f "required_status_checks[strict]=true" \
  -f "required_status_checks[contexts][]=All Checks Pass" \
  -f "enforce_admins=false" \
  -f "required_pull_request_reviews[dismiss_stale_reviews]=true" \
  -f "required_pull_request_reviews[required_approving_review_count]=1" \
  -f "restrictions=null" \
  -f "allow_force_pushes=false" \
  -f "allow_deletions=false"
```
