# Testing Guide for ha_adguard Module

This document provides comprehensive information about testing the ha_adguard Puppet module.

## Table of Contents

- [Test Types](#test-types)
- [Unit Tests](#unit-tests)
- [Acceptance Tests](#acceptance-tests)
- [Continuous Integration](#continuous-integration)
- [Troubleshooting](#troubleshooting)

## Test Types

The ha_adguard module includes two types of automated tests:

1. **Unit Tests (rspec-puppet)** - Fast, isolated tests that validate catalog compilation and resource behavior
2. **Acceptance Tests (Beaker)** - End-to-end tests that deploy the module on real systems using Docker containers

## Unit Tests

### Overview

Unit tests use rspec-puppet to test catalog compilation, resource relationships, and parameter validation without actually applying changes to a system.

**Coverage:** 1,862 examples across 8 test suites with 96.77% resource coverage

### Running Unit Tests

```bash
# Install dependencies
bundle install

# Run all unit tests
bundle exec rake spec

# Run tests for a specific class
bundle exec rspec spec/classes/init_spec.rb
bundle exec rspec spec/classes/keepalived_spec.rb

# Run a specific test scenario
bundle exec rspec spec/classes/init_spec.rb:15
```

### Unit Test Structure

Tests are organized by class:

```
spec/classes/
├── init_spec.rb          # Main class (ha_adguard)
├── user_spec.rb          # User/group management
├── install_spec.rb       # Binary installation
├── config_spec.rb        # Configuration management
├── service_spec.rb       # Systemd service
├── keepalived_spec.rb    # VRRP/VIP (HA)
├── sync_spec.rb          # Config synchronization
└── firewall_spec.rb      # Firewall rules
```

Each test file validates:
- Catalog compilation without errors
- Resource presence and attributes
- Conditional inclusion based on parameters
- Dependency relationships
- Parameter validation (failure cases)
- Multi-OS compatibility (Debian, Ubuntu, Rocky, AlmaLinux)

### Supported Operating Systems

Unit tests run on all supported platforms using `on_supported_os` from rspec-puppet-facts:

- Debian 11, 12, 13
- Ubuntu 20.04, 22.04, 24.04
- RedHat Enterprise Linux 8, 9
- CentOS 8, 9
- Rocky Linux 8, 9, 10
- AlmaLinux 9, 10

### Test Fixtures

Test fixtures are defined in [.fixtures.yml](.fixtures.yml) and include all module dependencies:

```bash
# Set up test fixtures
bundle exec rake spec_prep

# Clean test fixtures
bundle exec rake spec_clean
```

## Acceptance Tests

### Overview

Acceptance tests use Beaker to deploy the module on real Docker containers, testing actual functionality including:

- Service installation and startup
- DNS query resolution
- Web interface accessibility
- HA cluster failover
- Configuration synchronization
- Complete removal

### Prerequisites

- **Docker** installed and running
- **Ruby** 2.7+ with Bundler
- **Internet access** for downloading AdGuard Home binaries

```bash
# Verify Docker is running
docker ps

# Install acceptance test dependencies
bundle install --with acceptance
```

### Running Acceptance Tests

#### Quick Start

```bash
# Run single-node tests on Debian 12 (fastest, recommended for development)
bundle exec rake acceptance

# Run all acceptance tests on all platforms (comprehensive)
bundle exec rake acceptance:all
```

#### Platform-Specific Tests

```bash
# Debian 12 single-node
bundle exec rake acceptance:debian
BEAKER_set=debian12-docker bundle exec rspec spec/acceptance

# Rocky Linux 9 single-node
bundle exec rake acceptance:rocky
BEAKER_set=rocky9-docker bundle exec rspec spec/acceptance

# HA cluster (Debian 12 + Rocky 9)
bundle exec rake acceptance:cluster
BEAKER_set=ha-cluster-docker bundle exec rspec spec/acceptance/02_ha_cluster_spec.rb
```

#### Individual Test Files

```bash
# Single-node installation tests only
BEAKER_set=debian12-docker bundle exec rspec spec/acceptance/01_single_node_spec.rb

# HA cluster tests only
BEAKER_set=ha-cluster-docker bundle exec rspec spec/acceptance/02_ha_cluster_spec.rb
```

### Available Nodesets

Nodesets define the test environment configuration:

| Nodeset | File | Description | Use Case |
|---------|------|-------------|----------|
| **debian12-docker** | [spec/acceptance/nodesets/debian12-docker.yml](spec/acceptance/nodesets/debian12-docker.yml) | Single Debian 12 node | Quick single-node testing |
| **rocky9-docker** | [spec/acceptance/nodesets/rocky9-docker.yml](spec/acceptance/nodesets/rocky9-docker.yml) | Single Rocky 9 node | RedHat family testing |
| **ha-cluster-docker** | [spec/acceptance/nodesets/ha-cluster-docker.yml](spec/acceptance/nodesets/ha-cluster-docker.yml) | Debian 12 + Rocky 9 cluster | HA cluster testing |

### Acceptance Test Coverage

#### Single Node Tests ([01_single_node_spec.rb](spec/acceptance/01_single_node_spec.rb))

**Default parameters:**
- ✅ Catalog compilation
- ✅ Idempotency
- ✅ User/group creation
- ✅ Binary installation and capabilities
- ✅ Configuration file generation
- ✅ Systemd service management
- ✅ DNS service functionality (port 53)
- ✅ Web interface accessibility (port 3000)
- ✅ DNS query resolution

**Custom parameters:**
- ✅ Custom user/group
- ✅ Custom ports (DNS, web)
- ✅ Custom upstream DNS servers
- ✅ Configuration validation

**Removal (ensure => absent):**
- ✅ Service stop
- ✅ File/directory cleanup
- ✅ User/group removal

#### HA Cluster Tests ([02_ha_cluster_spec.rb](spec/acceptance/02_ha_cluster_spec.rb))

**Primary node:**
- ✅ AdGuard Home service
- ✅ Keepalived VRRP configuration
- ✅ Health check script
- ✅ VIP priority settings (150)
- ✅ DNS and web functionality

**Replica node:**
- ✅ AdGuard Home service
- ✅ Keepalived VRRP configuration
- ✅ adguardhome-sync service
- ✅ Sync configuration
- ✅ VIP priority settings (100)
- ✅ DNS and web functionality

**Cluster functionality:**
- ✅ VRRP priority validation
- ✅ Health check execution
- ✅ DNS resolution on both nodes
- ✅ Configuration synchronization
- ✅ Clean cluster removal

### Debugging Acceptance Tests

#### Keep Containers After Test

By default, Beaker destroys containers after tests. To keep them for debugging:

```bash
BEAKER_destroy=no BEAKER_set=debian12-docker bundle exec rspec spec/acceptance
```

#### Access Running Container

```bash
# List running containers
docker ps

# Access container shell
docker exec -it <container_id> /bin/bash

# Check logs
docker logs <container_id>
```

#### Increase Verbosity

```bash
# Enable debug output
BEAKER_debug=true bundle exec rake acceptance

# View beaker logs
cat log/latest/beaker_*.log
```

#### Run Specific Test Context

```bash
# Run only the "with default parameters" context
BEAKER_set=debian12-docker bundle exec rspec spec/acceptance/01_single_node_spec.rb -e "with default parameters"

# Run only removal tests
BEAKER_set=debian12-docker bundle exec rspec spec/acceptance/01_single_node_spec.rb -e "ensure => absent"
```

### Test Execution Time

Approximate execution times on a modern development machine:

| Test Type | Duration |
|-----------|----------|
| Unit tests (all platforms) | 30-35 minutes |
| Single-node acceptance (one platform) | 5-10 minutes |
| HA cluster acceptance | 10-15 minutes |
| All acceptance tests | 25-35 minutes |

**Tip:** Use `debian12-docker` for fastest feedback during development.

## Continuous Integration

### GitHub Actions Workflow

A sample GitHub Actions workflow for CI:

```yaml
name: CI

on: [push, pull_request]

jobs:
  unit:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: ruby/setup-ruby@v1
        with:
          ruby-version: '3.1'
          bundler-cache: true
      - run: bundle exec rake spec
      - run: bundle exec rake lint
      - run: bundle exec rake validate

  acceptance:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        nodeset: [debian12-docker, rocky9-docker]
    steps:
      - uses: actions/checkout@v3
      - uses: ruby/setup-ruby@v1
        with:
          ruby-version: '3.1'
          bundler-cache: true
      - run: bundle install --with acceptance
      - run: BEAKER_set=${{ matrix.nodeset }} bundle exec rspec spec/acceptance
```

## Troubleshooting

### Common Issues

#### Docker Permission Denied

```bash
# Add user to docker group
sudo usermod -aG docker $USER
newgrp docker
```

#### Container Port Conflicts

If you get "port already allocated" errors:

```bash
# Stop conflicting containers
docker stop $(docker ps -q)

# Or use different ports in test manifests
```

#### Slow Binary Downloads

Tests download AdGuard Home and adguardhome-sync binaries from GitHub. On slow connections:

```bash
# Pre-download binaries to speed up tests
wget https://github.com/AdguardTeam/AdGuardHome/releases/download/v0.107.52/AdGuardHome_linux_amd64.tar.gz
```

#### Test Timeouts

If services don't start within timeout periods:

1. Check Docker resources (CPU, memory)
2. Increase timeout values in spec_helper_acceptance.rb
3. Check container logs for errors

#### DNS Resolution Failures

DNS tests may fail if:
- Container doesn't have internet access
- Upstream DNS servers are unreachable
- systemd-resolved conflicts with AdGuard Home

```bash
# Debug DNS inside container
docker exec <container_id> dig @127.0.0.1 example.com
docker exec <container_id> systemctl status adguardhome
```

### Getting Help

If you encounter issues:

1. Check the [README](README.md) for requirements
2. Review test logs in `log/` directory
3. Search [existing issues](https://github.com/yourusername/ha_adguard/issues)
4. Open a new issue with:
   - Test command executed
   - Full error output
   - Beaker log file
   - Docker version (`docker --version`)
   - Ruby version (`ruby --version`)

## Best Practices

### For Contributors

1. **Always run unit tests** before submitting PRs: `bundle exec rake spec`
2. **Run acceptance tests** for changed components: `bundle exec rake acceptance`
3. **Maintain idempotency** - all manifests should be idempotent
4. **Add tests for new features** - both unit and acceptance
5. **Keep tests fast** - use Debian 12 nodeset for quick iteration
6. **Clean up** - ensure proper resource removal in `ensure => absent` scenarios

### For Module Users

1. **Start with unit tests** to validate your configuration compiles
2. **Use acceptance tests** to validate on your target platform
3. **Test upgrades** by running tests with different module versions
4. **Test in dev first** before deploying to production

## Additional Resources

- [rspec-puppet documentation](http://rspec-puppet.com/)
- [Beaker documentation](https://github.com/voxpupuli/beaker)
- [Puppet testing best practices](https://puppet.com/docs/puppet/latest/tests_smoke.html)
- [serverspec documentation](https://serverspec.org/)
