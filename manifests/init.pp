# Copyright (C) 2026 James Evans
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published
# by the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program. If not, see <https://www.gnu.org/licenses/>.
#
# @summary Manages AdGuard Home in high-availability configuration
#
# This module installs and configures AdGuard Home with optional HA support
# using Keepalived for VIP failover and adguardhome-sync for config replication.
#
# @param ensure
#   Ensure state of the module (present or absent)
#
# @param adguard_version
#   AdGuard Home version to install
#
# @param adguard_download_url
#   Base URL for AdGuard Home downloads
#
# @param install_dir
#   Installation directory for AdGuard Home
#
# @param config_dir
#   Configuration directory
#
# @param work_dir
#   Working directory for AdGuard Home data
#
# @param user
#   System user for running AdGuard Home
#
# @param group
#   System group for running AdGuard Home
#
# @param uid
#   User ID (optional, auto-assigned if undef)
#
# @param gid
#   Group ID (optional, auto-assigned if undef)
#
# @param adguard_config
#   Hash of additional AdGuard Home configuration (merged with defaults)
#
# @param bind_host
#   IP address to bind web UI
#
# @param bind_port
#   Port for web UI
#
# @param dns_port
#   Port for DNS service
#
# @param upstream_dns
#   Array of upstream DNS servers
#
# @param enable_dnssec
#   Enable DNSSEC validation
#
# @param enable_filtering
#   Enable DNS filtering
#
# @param ha_enabled
#   Enable high-availability mode
#
# @param ha_role
#   HA role (primary or replica)
#
# @param cluster_nodes
#   Array of cluster node FQDNs/IPs
#
# @param keepalived_enabled
#   Enable Keepalived for VIP management
#
# @param vip_address
#   Virtual IP address (required if keepalived_enabled)
#
# @param vip_address_v6
#   IPv6 virtual IP address with prefix length (optional, e.g. fd00:1234:5678:1::10/64)
#
# @param vrrp_priority
#   VRRP priority (higher = preferred master). Primary nodes should use a higher
#   value (e.g., 150) than replica nodes (e.g., 100) to enable automatic failback.
#   Both nodes MUST have different priorities for proper failover/failback behavior.
#
# @param vrrp_router_id
#   VRRP router ID
#
# @param vrrp_auth_pass
#   VRRP authentication password
#
# @param vrrp_interface
#   Network interface for VRRP
#
# @param health_check_interval
#   Health check interval in seconds
#
# @param health_check_timeout
#   Health check timeout in seconds
#
# @param sync_enabled
#   Enable adguardhome-sync
#
# @param sync_version
#   adguardhome-sync version to install
#
# @param sync_origin_url
#   Primary node URL for sync
#
# @param sync_username
#   AdGuard Home username for sync
#
# @param sync_password
#   AdGuard Home password for sync (Sensitive type)
#
# @param sync_interval
#   Sync interval in seconds
#
# @param sync_run_on_start
#   Run sync immediately on service start
#
# @param sync_api_enabled
#   Enable sync API
#
# @param sync_api_port
#   Sync API port
#
# @param sync_features
#   Array of features to synchronize
#
# @param manage_firewall
#   Manage firewall rules
#
# @param firewall_provider
#   Firewall provider (firewalld or iptables)
#
# @param manage_service
#   Manage AdGuard Home service
#
# @param service_ensure
#   Service ensure state
#
# @param service_enable
#   Enable service at boot
#
# @example Basic single-node installation
#   class { 'ha_adguard':
#     ensure => present,
#   }
#
# @example HA cluster - primary node
#   class { 'ha_adguard':
#     ensure              => present,
#     ha_enabled          => true,
#     ha_role             => 'primary',
#     cluster_nodes       => ['dns1.example.com', 'dns2.example.com'],
#     keepalived_enabled  => true,
#     vip_address         => '192.168.1.100',
#     vrrp_priority       => 150,
#   }
#
# @example HA cluster - replica node
#   class { 'ha_adguard':
#     ensure              => present,
#     ha_enabled          => true,
#     ha_role             => 'replica',
#     cluster_nodes       => ['dns1.example.com', 'dns2.example.com'],
#     keepalived_enabled  => true,
#     vip_address         => '192.168.1.100',
#     vrrp_priority       => 100,
#     sync_enabled        => true,
#     sync_origin_url     => 'http://dns1.example.com:3000',
#     sync_password       => Sensitive('supersecret'),
#   }
#
class ha_adguard (
  # Ensure state
  Enum['present', 'absent'] $ensure = 'present',

  # AdGuard Home version and installation
  String[1] $adguard_version = '0.107.52',
  String[1] $adguard_download_url = 'https://github.com/AdguardTeam/AdGuardHome/releases/download',
  Stdlib::Absolutepath $install_dir = '/opt/AdGuardHome',
  Stdlib::Absolutepath $config_dir = '/etc/adguardhome',
  Stdlib::Absolutepath $work_dir = '/var/lib/adguardhome',

  # System user
  String[1] $user = 'adguard',
  String[1] $group = 'adguard',
  Optional[Integer] $uid = undef,
  Optional[Integer] $gid = undef,

  # AdGuard Home configuration
  Hash $adguard_config = {},
  Stdlib::IP::Address $bind_host = '0.0.0.0',
  Stdlib::Port $bind_port = 3000,
  Stdlib::Port $dns_port = 53,
  Array[String[1]] $upstream_dns = [
    '1.1.1.1',
    '1.0.0.1',
    '8.8.8.8',
    '8.8.4.4',
  ],
  Boolean $enable_dnssec = true,
  Boolean $enable_filtering = true,

  # High Availability configuration
  Boolean $ha_enabled = false,
  Enum['primary', 'replica'] $ha_role = 'replica',
  Array[String[1]] $cluster_nodes = [],

  # Keepalived configuration
  Boolean $keepalived_enabled = false,
  Optional[Stdlib::IP::Address] $vip_address = undef,
  Optional[Stdlib::IP::Address::V6::CIDR] $vip_address_v6 = undef,
  Integer[0,255] $vrrp_priority = $ha_role ? { 'primary' => 150, 'replica' => 100 },
  Integer[1,255] $vrrp_router_id = 51,
  String[1] $vrrp_auth_pass = 'changeme',
  String[1] $vrrp_interface = 'eth0',
  Integer[1] $health_check_interval = 2,
  Integer[1] $health_check_timeout = 5,

  # Sync configuration (adguardhome-sync)
  Boolean $sync_enabled = false,
  String[1] $sync_version = '0.6.15',
  Optional[Stdlib::HTTPUrl] $sync_origin_url = undef,
  String[1] $sync_username = 'admin',
  Sensitive[String[1]] $sync_password = Sensitive('changeme'),
  Integer[1] $sync_interval = 600,
  Boolean $sync_run_on_start = true,
  Boolean $sync_api_enabled = true,
  Stdlib::Port $sync_api_port = 8080,
  Array[String[1]] $sync_features = [
    'general_settings',
    'query_log_config',
    'stats_config',
    'client_settings',
    'services',
    'filters',
    'dhcp_server_config',
    'dns_config',
  ],

  # Firewall management
  Boolean $manage_firewall = false,
  Enum['firewalld', 'iptables'] $firewall_provider = 'firewalld',

  # Service management
  Boolean $manage_service = true,
  Stdlib::Ensure::Service $service_ensure = 'running',
  Boolean $service_enable = true,
) {
  # Validation
  if $keepalived_enabled and !$vip_address {
    fail('vip_address is required when keepalived_enabled is true')
  }

  if $sync_enabled and !$sync_origin_url and $ha_role == 'replica' {
    fail('sync_origin_url is required when sync_enabled is true on replica nodes')
  }

  # Contain all classes and set dependencies
  if $ensure == 'present' {
    contain ha_adguard::user
    contain ha_adguard::install
    contain ha_adguard::config
    contain ha_adguard::service

    Class['ha_adguard::user']
    -> Class['ha_adguard::install']
    -> Class['ha_adguard::config']
    -> Class['ha_adguard::service']

    if $keepalived_enabled {
      contain ha_adguard::keepalived
      Class['ha_adguard::service'] -> Class['ha_adguard::keepalived']
    }

    if $sync_enabled and $ha_role == 'replica' {
      contain ha_adguard::sync
      Class['ha_adguard::service'] -> Class['ha_adguard::sync']
    }

    if $manage_firewall {
      contain ha_adguard::firewall
      Class['ha_adguard::service'] -> Class['ha_adguard::firewall']
    }
  } else {
    # Reverse dependency order for removal
    if $manage_firewall {
      contain ha_adguard::firewall
    }

    if $sync_enabled {
      contain ha_adguard::sync
    }

    if $keepalived_enabled {
      contain ha_adguard::keepalived
    }

    contain ha_adguard::service
    contain ha_adguard::config
    contain ha_adguard::install
    contain ha_adguard::user

    if $manage_firewall and $sync_enabled {
      Class['ha_adguard::firewall']
      -> Class['ha_adguard::sync']
    }

    if $sync_enabled and $keepalived_enabled {
      Class['ha_adguard::sync']
      -> Class['ha_adguard::keepalived']
    }

    if $keepalived_enabled {
      Class['ha_adguard::keepalived']
      -> Class['ha_adguard::service']
    }

    if $sync_enabled {
      Class['ha_adguard::sync']
      -> Class['ha_adguard::service']
    }

    Class['ha_adguard::service']
    -> Class['ha_adguard::config']
    -> Class['ha_adguard::install']
    -> Class['ha_adguard::user']
  }
}
