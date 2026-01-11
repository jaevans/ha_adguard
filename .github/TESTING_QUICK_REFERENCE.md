# Testing Quick Reference

Quick reference for running tests on the ha_adguard module.

## Unit Tests (Fast - 30 minutes)

```bash
bundle exec rake spec              # All unit tests
bundle exec rspec spec/classes/    # Just class tests
bundle exec rake validate          # Syntax validation
bundle exec rake lint              # Puppet-lint
```

## Acceptance Tests (Require Docker)

### Quick Single-Node Tests (5-10 minutes each)

```bash
bundle exec rake acceptance        # Debian 12 (default, fastest)
bundle exec rake acceptance:rocky  # Rocky Linux 9
```

### HA Cluster Tests (10-15 minutes)

```bash
bundle exec rake acceptance:cluster
```

### All Platforms (25-35 minutes)

```bash
bundle exec rake acceptance:all
```

## Development Workflow

```bash
# 1. Make changes to manifests
vim manifests/config.pp

# 2. Run quick validation
bundle exec rake validate lint

# 3. Run unit tests
bundle exec rake spec

# 4. Run acceptance test (single platform)
bundle exec rake acceptance

# 5. If all pass, run full test suite
bundle exec rake acceptance:all
```

## Debugging

```bash
# Keep containers after test
BEAKER_destroy=no BEAKER_set=debian12-docker bundle exec rspec spec/acceptance

# Run specific test file
BEAKER_set=debian12-docker bundle exec rspec spec/acceptance/01_single_node_spec.rb

# Run specific test context
BEAKER_set=debian12-docker bundle exec rspec spec/acceptance/01_single_node_spec.rb -e "with default parameters"

# Enable debug output
BEAKER_debug=true bundle exec rake acceptance
```

## Continuous Integration

```bash
# Full CI pipeline (recommended before PR)
bundle exec rake validate
bundle exec rake lint
bundle exec rake spec
bundle exec rake acceptance:debian
```

For more details, see [TESTING.md](../TESTING.md)
