# ha_adguard

[![Puppet Forge](https://img.shields.io/puppetforge/v/james/ha_adguard.svg)](https://forge.puppet.com/james/ha_adguard)
[![Build Status](https://img.shields.io/github/workflow/status/yourusername/ha_adguard/CI)](https://github.com/yourusername/ha_adguard/actions)

A production-ready Puppet module for managing [AdGuard Home](https://github.com/AdguardTeam/AdGuardHome) with high-availability support.

## Table of Contents

- [Description](#description)
- [Features](#features)
- [Requirements](#requirements)
- [Installation](#installation)
- [Usage](#usage)
  - [Single Node](#single-node)
  - [High Availability Cluster](#high-availability-cluster)
- [Reference](#reference)
- [Limitations](#limitations)
- [Development](#development)
- [License](#license)

## Description

This module installs and configures AdGuard Home, a network-wide software for blocking ads and tracking. It provides full support for high-availability deployments using:

- **Keepalived** for VRRP (Virtual Router Redundancy Protocol) and VIP failover
- **adguardhome-sync** for configuration synchronization between cluster nodes
- **Automatic firewall management** via puppetlabs/firewall
- **Systemd service management** via puppet/systemd

The module follows a composition-over-implementation strategy, wrapping well-maintained Puppet Forge modules rather than writing custom implementations.

## Features

- **Single-node or HA cluster deployment** with active/passive configuration
- **Automatic binary installation** from GitHub releases with architecture detection
- **Deep-merge configuration** allowing partial YAML overrides
- **Health checking** for VRRP with DNS functional tests
- **Automatic service management** with systemd
- **Firewall integration** supporting both firewalld and iptables
- **Sensitive data handling** for passwords and API credentials
- **Multi-OS support**: Debian 11/12/13, Ubuntu 20.04/22.04/24.04, Rocky 8/9/10, AlmaLinux 9/10

## Requirements

### Puppet Modules

This module depends on the following Puppet Forge modules:

- [puppetlabs/stdlib](https://forge.puppet.com/puppetlabs/stdlib) (>= 9.0.0 < 10.0.0)
- [puppet/archive](https://forge.puppet.com/puppet/archive) (>= 7.0.0 < 9.0.0)
- [puppetlabs/firewall](https://forge.puppet.com/puppetlabs/firewall) (>= 8.0.0 < 9.0.0)
- [puppet/systemd](https://forge.puppet.com/puppet/systemd) (>= 7.0.0 < 9.0.0)
- [puppet/keepalived](https://forge.puppet.com/puppet/keepalived) (>= 6.0.0 < 7.0.0)
- [puppetlabs/concat](https://forge.puppet.com/puppetlabs/concat) (>= 8.0.0 < 10.0.0)

### System Requirements

- **Puppet**: 8.x
- **Operating Systems**: See [metadata.json](metadata.json) for full list
- **Network**: Port 53 (DNS), 3000 (Web UI), 80/443 (optional)

## Installation

Install from Puppet Forge:

```bash
puppet module install james-ha_adguard
```

Or add to your Puppetfile:

```puppet
mod 'james-ha_adguard', '1.0.0'
```

## Usage

### Single Node

Basic single-node installation with default settings:

```puppet
class { 'ha_adguard':
  ensure => present,
}
```

Custom configuration with specific DNS settings:

```puppet
class { 'ha_adguard':
  ensure       => present,
  bind_host    => '0.0.0.0',
  bind_port    => 3000,
  dns_port     => 53,
  upstream_dns => [
    '1.1.1.1',
    '1.0.0.1',
    '2606:4700:4700::1111',
    '2606:4700:4700::1001',
  ],
  adguard_config => {
    'dns' => {
      'ratelimit' => 20,
      'blocked_response_ttl' => 10,
    },
  },
}
```

### High Availability Cluster

#### Primary Node

```puppet
class { 'ha_adguard':
  ensure             => present,
  ha_enabled         => true,
  ha_role            => 'primary',

  # Keepalived VIP configuration
  keepalived_enabled => true,
  vip_address        => '192.168.1.100',
  vip_interface      => 'eth0',
  vrrp_priority      => 150,
  vrrp_router_id     => 51,
  vrrp_auth_pass     => Sensitive('secure_password_here'),

  # DNS and web interface settings
  bind_host          => '0.0.0.0',
  bind_port          => 3000,
  dns_port           => 53,

  # Cluster nodes for health checks
  cluster_nodes      => [
    '192.168.1.10',  # primary
    '192.168.1.11',  # replica
  ],

  # Firewall management
  manage_firewall    => true,

  # AdGuard admin credentials
  sync_username      => 'admin',
  sync_password      => Sensitive('admin_password'),
}
```

#### Replica Node

```puppet
class { 'ha_adguard':
  ensure             => present,
  ha_enabled         => true,
  ha_role            => 'replica',

  # Keepalived VIP configuration
  keepalived_enabled => true,
  vip_address        => '192.168.1.100',
  vip_interface      => 'eth0',
  vrrp_priority      => 100,  # Lower than primary
  vrrp_router_id     => 51,
  vrrp_auth_pass     => Sensitive('secure_password_here'),

  # Configuration sync settings
  sync_enabled       => true,
  sync_origin_url    => 'http://192.168.1.10:3000',
  sync_username      => 'admin',
  sync_password      => Sensitive('admin_password'),
  sync_interval      => 600,  # Sync every 10 minutes

  # DNS and web interface settings
  bind_host          => '0.0.0.0',
  bind_port          => 3000,
  dns_port           => 53,

  # Cluster nodes for health checks
  cluster_nodes      => [
    '192.168.1.10',  # primary
    '192.168.1.11',  # replica
  ],

  # Firewall management
  manage_firewall    => true,
}
```

#### Using Hiera

For easier management, use Hiera with node-specific data:

**data/nodes/adguard-primary.example.com.yaml:**
```yaml
---
ha_adguard::ensure: 'present'
ha_adguard::ha_enabled: true
ha_adguard::ha_role: 'primary'
ha_adguard::keepalived_enabled: true
ha_adguard::vip_address: '192.168.1.100'
ha_adguard::vrrp_priority: 150
ha_adguard::sync_username: 'admin'
ha_adguard::sync_password: >
  ENC[PKCS7,MIIBeQYJKoZIhvcNAQcDoIIBajCCAWYCAQAxggEhMIIBHQIBADAFMAACAQEw...]
```

**data/nodes/adguard-replica.example.com.yaml:**
```yaml
---
ha_adguard::ensure: 'present'
ha_adguard::ha_enabled: true
ha_adguard::ha_role: 'replica'
ha_adguard::keepalived_enabled: true
ha_adguard::vip_address: '192.168.1.100'
ha_adguard::vrrp_priority: 100
ha_adguard::sync_enabled: true
ha_adguard::sync_origin_url: 'http://192.168.1.10:3000'
ha_adguard::sync_username: 'admin'
ha_adguard::sync_password: >
  ENC[PKCS7,MIIBeQYJKoZIhvcNAQcDoIIBajCCAWYCAQAxggEhMIIBHQIBADAFMAACAQEw...]
```

Then in your manifest:

```puppet
include ha_adguard
```

## Reference

### Main Class Parameters

#### Installation Parameters

- `ensure` (Enum['present', 'absent']): Whether AdGuard Home should be installed. Default: `'present'`
- `adguard_version` (String): AdGuard Home version to install. Default: `'0.107.52'`
- `sync_version` (String): adguardhome-sync version to install. Default: `'0.6.15'`
- `install_dir` (Stdlib::Absolutepath): Installation directory. Default: `'/opt/AdGuardHome'`
- `config_dir` (Stdlib::Absolutepath): Configuration directory. Default: `'/etc/adguardhome'`
- `work_dir` (Stdlib::Absolutepath): Working directory for data files. Default: `'/var/lib/adguardhome'`

#### User/Group Parameters

- `user` (String): System user for AdGuard Home. Default: `'adguard'`
- `group` (String): System group for AdGuard Home. Default: `'adguard'`
- `user_uid` (Optional[Integer]): UID for the system user. Default: `undef`
- `group_gid` (Optional[Integer]): GID for the system group. Default: `undef`

#### DNS Configuration

- `bind_host` (Stdlib::IP::Address): IP address to bind web interface. Default: `'0.0.0.0'`
- `bind_port` (Stdlib::Port): Web interface port. Default: `3000`
- `dns_port` (Stdlib::Port): DNS server port. Default: `53`
- `upstream_dns` (Array[String]): Upstream DNS servers. Default: `['1.1.1.1', '1.0.0.1', '8.8.8.8', '8.8.4.4']`
- `enable_dnssec` (Boolean): Enable DNSSEC validation. Default: `true`
- `enable_filtering` (Boolean): Enable ad filtering. Default: `true`

#### High Availability Parameters

- `ha_enabled` (Boolean): Enable HA mode. Default: `false`
- `ha_role` (Enum['primary', 'replica']): HA node role. Default: `'primary'`
- `cluster_nodes` (Array[Stdlib::IP::Address]): List of cluster node IPs. Default: `[]`

#### Keepalived Parameters

- `keepalived_enabled` (Boolean): Enable Keepalived for VIP. Default: `false`
- `vip_address` (Optional[Stdlib::IP::Address]): Virtual IP address. Required when keepalived_enabled is true.
- `vip_interface` (Optional[String]): Network interface for VIP. Default: `'eth0'`
- `vrrp_priority` (Integer[1,254]): VRRP priority (higher = master). Default: `100`
- `vrrp_router_id` (Integer[1,255]): VRRP router ID. Default: `51`
- `vrrp_auth_pass` (Sensitive[String]): VRRP authentication password. Default: `Sensitive('changeme')`
- `health_check_interval` (Integer[1,60]): Health check interval in seconds. Default: `2`
- `health_check_timeout` (Integer[1,30]): Health check timeout in seconds. Default: `5`

#### Sync Parameters

- `sync_enabled` (Boolean): Enable adguardhome-sync. Default: `false`
- `sync_origin_url` (Optional[Stdlib::HTTPUrl]): Primary node URL for sync. Required when sync_enabled is true on replica.
- `sync_username` (String): AdGuard admin username. Default: `'admin'`
- `sync_password` (Sensitive[String]): AdGuard admin password. Default: `Sensitive('changeme')`
- `sync_interval` (Integer[60,86400]): Sync interval in seconds. Default: `600`
- `sync_run_on_start` (Boolean): Run sync on service start. Default: `true`
- `sync_api_enabled` (Boolean): Enable sync API. Default: `true`
- `sync_api_port` (Stdlib::Port): Sync API port. Default: `8080`
- `sync_features` (Array[String]): Features to synchronize. Default: all features

#### Firewall Parameters

- `manage_firewall` (Boolean): Manage firewall rules. Default: `false`
- `firewall_provider` (Enum['firewalld', 'iptables']): Firewall provider. Default: `'firewalld'`

#### Service Parameters

- `manage_service` (Boolean): Manage systemd service. Default: `true`
- `service_ensure` (Stdlib::Ensure::Service): Service state. Default: `'running'`
- `service_enable` (Boolean): Enable service on boot. Default: `true`

#### Advanced Configuration

- `adguard_config` (Hash): Deep-merged with default AdGuard configuration. Default: `{}`

### Classes

This module uses a hierarchical class structure:

- `ha_adguard`: Main class
- `ha_adguard::user`: Manages system user and group
- `ha_adguard::install`: Downloads and installs binaries
- `ha_adguard::config`: Manages configuration files
- `ha_adguard::service`: Manages systemd service
- `ha_adguard::keepalived`: Manages Keepalived (if enabled)
- `ha_adguard::sync`: Manages adguardhome-sync (if enabled on replica)
- `ha_adguard::firewall`: Manages firewall rules (if enabled)

## Limitations

- **HA sync requires replica role**: `sync_enabled` only works when `ha_role` is set to `'replica'`
- **Keepalived requires VIP**: When `keepalived_enabled` is true, `vip_address` must be set
- **No multi-master support**: Only active/passive HA is supported (primary + replica)
- **Linux only**: This module is designed for Linux systems with systemd
- **Architecture support**: amd64, arm64, armv7 (no support for sparc, mips, etc.)

## Development

### Running Tests

#### Unit Tests

```bash
# Install dependencies
bundle install

# Run unit tests (rspec-puppet)
bundle exec rake spec

# Run validation (syntax, lint)
bundle exec rake validate
bundle exec rake lint

# Run all checks
bundle exec rake test
```

#### Acceptance Tests

Acceptance tests use Beaker with Docker to test the module on real systems. You'll need Docker installed and running.

```bash
# Install acceptance test dependencies
bundle install --with acceptance

# Run acceptance tests on Debian 12 (default)
bundle exec rake acceptance

# Run acceptance tests on specific platforms
bundle exec rake acceptance:debian   # Debian 12
bundle exec rake acceptance:rocky    # Rocky Linux 9
bundle exec rake acceptance:cluster  # HA cluster (Debian 12 + Rocky 9)

# Run all acceptance tests on all platforms
bundle exec rake acceptance:all
```

**Available nodesets:**
- `debian12-docker.yml` - Single Debian 12 node
- `rocky9-docker.yml` - Single Rocky Linux 9 node
- `ha-cluster-docker.yml` - Two-node HA cluster (Debian 12 primary + Rocky 9 replica)

**Acceptance test coverage:**
- Single-node installation with default parameters
- Single-node installation with custom parameters
- Service lifecycle (start, stop, restart)
- DNS functionality testing
- Web interface accessibility
- HA cluster setup (primary + replica)
- VRRP/Keepalived configuration
- Configuration synchronization
- Health checks and failover
- Complete removal (ensure => absent)

**Running specific test files:**

```bash
# Run only single-node tests
BEAKER_set=debian12-docker bundle exec rspec spec/acceptance/01_single_node_spec.rb

# Run only HA cluster tests
BEAKER_set=ha-cluster-docker bundle exec rspec spec/acceptance/02_ha_cluster_spec.rb

# Keep containers after tests for debugging
BEAKER_destroy=no BEAKER_set=debian12-docker bundle exec rspec spec/acceptance
```

### Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes with tests
4. Run tests and validation
5. Submit a pull request

## License

Apache License 2.0

Copyright 2024 James

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
