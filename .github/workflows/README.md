# GitHub Actions Workflows

This directory contains GitHub Actions workflows for automated testing of the ha_adguard Puppet module.

## Workflows

### Unit Tests (`unit-tests.yml`)

Runs on every push and pull request to main/master branches.

**Jobs:**
- `validate`: Validates Puppet manifests, templates, and Ruby syntax
- `spec`: Runs RSpec unit tests across all supported platforms

**Trigger:** Automatically runs for all contributors

**Duration:** ~30-35 minutes

### Acceptance Tests (`acceptance-tests.yml`)

Runs Beaker acceptance tests using Docker containers.

**Jobs:**
- `authorize`: Security gate for non-collaborator PRs
- `acceptance-debian`: Tests on Debian 12
- `acceptance-rocky`: Tests on Rocky Linux 9
- `acceptance-cluster`: Tests HA cluster configuration

**Trigger:** 
- Automatically for collaborators, members, and owners
- Requires manual approval (via `safe-to-test` label) for non-collaborators

**Duration:** ~25-35 minutes total (jobs run in parallel)

## Security Model

### Why `pull_request_target`?

The acceptance test workflow uses `pull_request_target` instead of `pull_request` for security reasons:

1. **Resource Protection**: Beaker tests spin up Docker containers and download binaries, which could be abused
2. **Code Injection Prevention**: Malicious PRs could modify workflows or test code to exfiltrate secrets
3. **CI Cost Control**: Prevents spam PRs from consuming excessive CI resources

### How It Works

1. **For Collaborators**: Tests run automatically
   - Repository owners, members, and collaborators are trusted
   - Their PRs trigger tests immediately

2. **For Non-Collaborators**: Manual approval required
   - Maintainers review the PR code first
   - Add the `safe-to-test` label to approve testing
   - Tests then run with the same permissions as collaborator PRs

3. **Safe Checkout**: 
   - The workflow checks out the **base branch** code, not the PR branch
   - This prevents malicious workflow modifications from executing
   - Beaker still tests the PR code via module installation

### Approving Non-Collaborator PRs

To approve a PR from a non-collaborator:

1. Review the PR code thoroughly
2. Ensure no malicious changes to workflows, tests, or dependencies
3. Add the `safe-to-test` label to the PR
4. Tests will run automatically

To create the label if it doesn't exist:
```bash
gh label create safe-to-test --description "Approve CI runs for non-collaborator PRs" --color 0e8a16
```

## Best Practices

### For Contributors

1. **Run tests locally first**: Use `bundle exec rake spec` and `bundle exec rake acceptance`
2. **Keep PRs focused**: Smaller PRs are easier to review and test
3. **Don't modify workflows** unless necessary: Workflow changes trigger extra scrutiny

### For Maintainers

1. **Review before labeling**: Always check PR code before adding `safe-to-test`
2. **Watch for suspicious changes**:
   - New dependencies without justification
   - Workflow modifications
   - Test changes that disable security checks
   - Network requests to unknown domains
3. **Remove label if PR updates**: Re-review after new commits

## Troubleshooting

### Tests Don't Run on My PR

**If you're a non-collaborator:**
- This is expected - wait for a maintainer to review and approve
- You can run tests locally: See [TESTING.md](../../TESTING.md)

**If you're a collaborator:**
- Check that you're logged into GitHub with your authorized account
- Verify you have write access to the repository

### Tests Fail on CI But Pass Locally

Common causes:
1. **Docker environment differences**: CI uses fresh containers
2. **Network timeouts**: CI may have slower internet connections
3. **Race conditions**: Timing issues in parallel execution
4. **Missing dependencies**: Check that Gemfile.lock is up to date

See [TESTING.md](../../TESTING.md) for detailed troubleshooting.

## References

- [GitHub Actions: pull_request_target security](https://securitylab.github.com/research/github-actions-preventing-pwn-requests/)
- [Puppet module testing best practices](https://voxpupuli.org/docs/testing/)
- [Beaker documentation](https://github.com/voxpupuli/beaker)
