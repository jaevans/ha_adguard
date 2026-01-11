# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is **ha_adguard**, a production-ready Puppet 8 module for managing AdGuard Home in high-availability configuration. The module supports active/passive clustering with Keepalived VIP failover and adguardhome-sync for configuration replication between nodes.

**Critical architectural decision**: This module uses **OpenVox** (not Puppet) as it's fully opensource, along with **OpenFact** instead of Facter. All Gemfile dependencies reference openvox/openfact, not puppet/facter.

## Development Commands

### Testing
```bash
# Run all unit tests (rspec-puppet)
bundle exec rake spec

# Run specific test file
bundle exec rspec spec/classes/init_spec.rb

# Run specific test scenario
bundle exec rspec spec/classes/init_spec.rb:15

# Run all validation (manifests, templates, ruby files)
bundle exec rake validate

# Run puppet-lint
bundle exec rake lint

# Run syntax checks
bundle exec rake syntax
```

### Installation and Setup
```bash
# Install all dependencies
bundle install

# Update dependencies (including fixtures for testing)
bundle update
```

## Architecture Overview

### Module Composition Strategy

This module follows a **composition over custom implementation** philosophy by wrapping well-maintained Puppet Forge modules rather than writing custom implementations:

- **puppet/keepalived** - VRRP/VIP management (no custom keepalived.conf templates)
- **puppet/systemd** - Systemd unit file management (automatic daemon-reload)
- **puppetlabs/firewall** - Cross-platform firewall rules (works with both firewalld and iptables)
- **puppet/archive** - Binary downloads from GitHub releases

This reduces custom code by ~40% and provides better error handling and automatic cleanup.

### Class Hierarchy and Execution Flow

**Installation flow** (ensure => present):
```
ha_adguard::user          # Creates system user/group and home directory
  ↓
ha_adguard::install       # Downloads binaries, sets capabilities
  ↓
ha_adguard::config        # Deep-merges config hash, generates YAML
  ↓
ha_adguard::service       # Creates systemd units via puppet/systemd
  ↓
├─ ha_adguard::keepalived # VRRP via puppet/keepalived (if enabled)
├─ ha_adguard::sync       # Config replication (replica nodes only)
└─ ha_adguard::firewall   # Firewall rules via puppetlabs/firewall (if enabled)
```

**Removal flow** (ensure => absent):
Reverse order with proper dependencies to prevent failures during cleanup.

### Configuration Synchronization

**Critical discovery**: AdGuard Home has NO built-in synchronization. This module uses `adguardhome-sync` by bakito (industry-standard tool) for configuration replication.

- **Primary nodes**: Run AdGuard Home only
- **Replica nodes**: Run AdGuard Home + adguardhome-sync service
- Sync is **replica-only** to prevent sync conflicts (primary is source of truth)

### Binary Installation

Architecture detection via OpenFact facts:
- Maps `x86_64`/`amd64` → `amd64`
- Maps `aarch64` → `arm64`
- Maps `armv7l` → `armv7`
- Fails on unsupported architectures (e.g., sparc)

Binaries downloaded from GitHub releases with checksum verification via puppet/archive module.

Linux capabilities (`CAP_NET_BIND_SERVICE`, `CAP_NET_RAW`) set via `setcap` to allow binding to port 53 without running as root.

### Deep Merge Configuration

The config.pp class uses `stdlib::deep_merge()` to merge user-provided configuration hashes with comprehensive defaults. This allows:
- Full YAML override capability via `adguard_config` parameter
- Sane defaults for all AdGuard Home settings
- Partial overrides (user only specifies what they want to change)

### Testing Architecture

**Unit tests** (rspec-puppet):
- Uses `on_supported_os` from rspec-puppet-facts for multi-OS testing
- Tests run against: Debian 11/12/13, Ubuntu 20.04/22.04/24.04, Rocky 8/9/10, AlmaLinux 9/10
- Each spec file tests a single class in isolation with pre_condition for dependencies
- Coverage includes: default params, custom params, HA scenarios, validation, removal

**Acceptance tests** (Beaker):
- Planned nodesets for single-node and two-node clusters
- Tests: basic install, HA failover, config sync, removal

### Parameter Validation

Key validations in init.pp:
- `keepalived_enabled => true` requires `vip_address` to be set
- `sync_enabled => true` on replica requires `sync_origin_url` to be set
- Uses Puppet 8 data types (Stdlib::IP::Address, Stdlib::Port, Sensitive[String])

## Module-Specific Patterns

### Sensitive Data Handling
Always use `Sensitive[String]` for passwords. In EPP templates, unwrap with `.unwrap`:
```puppet
password: <%= $password.unwrap %>
```

### Conditional Class Inclusion
Classes are conditionally included based on features:
- keepalived.pp: only when `keepalived_enabled => true`
- sync.pp: only when `sync_enabled => true` AND `ha_role == 'replica'`
- firewall.pp: only when `manage_firewall => true`

### Systemd Unit Management
Use puppet/systemd module, NOT manual file resources:
```puppet
systemd::unit_file { 'adguardhome.service':
  content => epp('ha_adguard/adguardhome.service.epp'),
  enable  => true,
  active  => true,
}
```

The module handles daemon-reload automatically.

### Health Check Pattern
Keepalived health checks (in templates/health_check.sh.epp):
1. Check process running (pgrep)
2. Check port listening (ss)
3. Perform functional test (dig DNS query)
4. Timeout after 5 seconds

## Important Implementation Notes

### Why VRRP State is Always BACKUP
Both primary and replica nodes use `state => 'BACKUP'` in VRRP configuration to prevent split-brain scenarios. The `priority` parameter determines which node becomes master (higher priority wins).

### Why Sync is Replica-Only
Running sync on primary nodes would create circular sync loops. Primary is always the source of truth; replicas pull configuration from primary.

### Template Reduction
Originally planned 6 templates; reduced to 4 by using puppet/keepalived module:
- ✅ adguardhome.service.epp
- ✅ health_check.sh.epp
- ✅ sync_config.yaml.epp
- ✅ sync.service.epp
- ❌ keepalived.conf.epp (NOT needed - puppet/keepalived handles it)

### Hiera Data Layer
Module uses Hiera 5 with hierarchy:
1. Per-node data: `data/nodes/%{trusted.certname}.yaml`
2. Per-OS family: `data/os/%{facts.os.family}.yaml`
3. Common defaults: `data/common.yaml`

OS-specific differences (e.g., network interface names: `ens3` for Debian, `ens192` for RedHat).

## Common Pitfalls

1. **Don't use puppet-lint's 140chars check** - Disabled in Rakefile for readability
2. **Test fixtures must include ALL dependencies** - .fixtures.yml includes stdlib, archive, firewall, systemd, keepalived
3. **Architecture detection uses facts['os']['architecture']** - NOT facts['architecture']
4. **Config file mode must be 0600** - Contains sensitive credentials
5. **Service must subscribe to config changes** - Ensures restart on config updates
6. **Removal must reverse dependency order** - firewall → sync → keepalived → service → config → install → user
7. **Test after every change** - Use `bundle exec rake spec` frequently
