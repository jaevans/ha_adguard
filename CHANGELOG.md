# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2024-01-10

### Added

#### Core Features
- Initial release of ha_adguard module for Puppet 8
- Single-node and high-availability AdGuard Home installation
- Support for AdGuard Home version 0.107.52
- Architecture detection for amd64, arm64, and armv7 platforms
- Automatic binary downloads from GitHub releases with checksum verification
- Deep-merge configuration allowing partial YAML overrides
- Sensitive data handling for passwords and API credentials

#### High Availability Features
- Active/passive HA clustering with Keepalived
- VRRP (Virtual Router Redundancy Protocol) configuration
- Floating VIP (Virtual IP) support for seamless failover
- Primary and replica node roles
- Configuration synchronization via adguardhome-sync (v0.6.15)
- Health checks with DNS functional testing
- Automatic failover on node failure

#### System Integration
- Systemd service management via puppet/systemd module
- Automatic firewall rule management via puppetlabs/firewall
- Support for both firewalld and iptables providers
- Linux capabilities (CAP_NET_BIND_SERVICE, CAP_NET_RAW) for non-root port binding
- System user/group creation with configurable UID/GID

#### Configuration Management
- Hiera 5 integration with hierarchical data lookup
- OS-specific defaults for Debian and RedHat families
- Per-node configuration support via Hiera
- Comprehensive parameter validation
- Conditional class inclusion based on features

#### Testing and Quality
- Comprehensive rspec-puppet unit tests with 96.77% coverage (1,862 examples)
- Multi-OS testing across Debian 11/12/13, Ubuntu 20.04/22.04/24.04, Rocky 8/9/10, AlmaLinux 9/10
- Beaker acceptance tests for single-node and HA cluster deployments
- Docker-based acceptance testing with Debian 12 and Rocky 9 nodesets
- Functional testing of DNS resolution, web interface, and HA failover
- Puppet-lint validation with arrow alignment checks
- Syntax validation for manifests, templates, and Ruby files
- EPP template validation

#### Documentation
- Complete README with installation and usage examples
- Example manifests for single-node and HA deployments
- Hiera-based configuration examples
- Comprehensive parameter reference (50+ parameters)
- Module architecture documentation in CLAUDE.md
- Detailed testing guide (TESTING.md) with unit and acceptance test instructions
- CHANGELOG following Keep a Changelog format

### Module Composition
- Uses puppet/keepalived for VRRP/VIP management (no custom keepalived.conf)
- Uses puppet/systemd for systemd unit management
- Uses puppetlabs/firewall for cross-platform firewall rules
- Uses puppet/archive for binary downloads
- Uses puppetlabs/stdlib for utility functions
- Uses puppetlabs/concat for file concatenation (keepalived dependency)

### Supported Operating Systems
- Debian 11, 12, 13
- Ubuntu 20.04, 22.04, 24.04
- RedHat Enterprise Linux 8, 9
- CentOS 8, 9
- Rocky Linux 8, 9, 10
- AlmaLinux 9, 10

### Dependencies
- puppetlabs/stdlib (>= 9.0.0 < 10.0.0)
- puppet/archive (>= 7.0.0 < 9.0.0)
- puppetlabs/firewall (>= 8.0.0 < 9.0.0)
- puppet/systemd (>= 7.0.0 < 9.0.0)
- puppet/keepalived (>= 6.0.0 < 7.0.0)
- puppetlabs/concat (>= 8.0.0 < 10.0.0)

### Templates
- adguardhome.service.epp - AdGuard Home systemd unit
- health_check.sh.epp - VRRP health check script with DNS testing
- sync.service.epp - adguardhome-sync systemd unit
- sync_config.yaml.epp - adguardhome-sync configuration

### Classes
- ha_adguard - Main class for module entry point
- ha_adguard::user - System user and group management
- ha_adguard::install - Binary installation and capabilities
- ha_adguard::config - Configuration file generation with deep merge
- ha_adguard::service - Systemd service management
- ha_adguard::keepalived - VRRP/VIP configuration (conditional)
- ha_adguard::sync - Configuration synchronization (conditional, replica only)
- ha_adguard::firewall - Firewall rule management (conditional)

### Parameters

#### Installation
- `ensure` - Install or remove AdGuard Home
- `adguard_version` - AdGuard Home version
- `sync_version` - adguardhome-sync version
- `install_dir` - Installation directory
- `config_dir` - Configuration directory
- `work_dir` - Working directory

#### DNS Configuration
- `bind_host` - Web interface bind address
- `bind_port` - Web interface port
- `dns_port` - DNS server port
- `upstream_dns` - Upstream DNS servers
- `enable_dnssec` - Enable DNSSEC validation
- `enable_filtering` - Enable ad filtering

#### High Availability
- `ha_enabled` - Enable HA mode
- `ha_role` - Node role (primary/replica)
- `cluster_nodes` - Cluster node IP addresses

#### Keepalived
- `keepalived_enabled` - Enable Keepalived
- `vip_address` - Virtual IP address
- `vip_interface` - Network interface for VIP
- `vrrp_priority` - VRRP priority
- `vrrp_router_id` - VRRP router ID
- `vrrp_auth_pass` - VRRP authentication password
- `health_check_interval` - Health check interval
- `health_check_timeout` - Health check timeout

#### Synchronization
- `sync_enabled` - Enable config sync
- `sync_origin_url` - Primary node URL
- `sync_username` - AdGuard admin username
- `sync_password` - AdGuard admin password
- `sync_interval` - Sync interval in seconds
- `sync_run_on_start` - Sync on service start
- `sync_api_enabled` - Enable sync API
- `sync_api_port` - Sync API port
- `sync_features` - Features to synchronize

#### Firewall
- `manage_firewall` - Manage firewall rules
- `firewall_provider` - Firewall provider (firewalld/iptables)

#### Service
- `manage_service` - Manage systemd service
- `service_ensure` - Service state
- `service_enable` - Enable on boot

### Known Limitations
- HA sync only works on replica nodes (by design)
- Keepalived requires vip_address to be set when enabled
- No multi-master support (active/passive only)
- Linux-only with systemd requirement
- Architecture support limited to amd64, arm64, armv7

### Design Decisions
- Uses VRRP state 'BACKUP' for both nodes to prevent split-brain
- Priority determines which node becomes master
- Sync is replica-only to prevent circular sync loops
- Configuration deep-merge allows partial overrides
- Composition over implementation using Forge modules
- Template reduction by leveraging puppet/keepalived

[1.0.0]: https://github.com/yourusername/ha_adguard/releases/tag/v1.0.0
