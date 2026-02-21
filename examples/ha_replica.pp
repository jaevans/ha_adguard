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
# High-availability AdGuard Home - Replica Node
#
# This example demonstrates a replica node in an HA cluster with:
# - Keepalived for VIP failover (BACKUP state)
# - Lower VRRP priority (becomes backup)
# - adguardhome-sync for config replication
# - Health checks for VRRP
# - Firewall management
#
# Usage:
#   puppet apply examples/ha_replica.pp

class { 'ha_adguard':
  ensure => present,

  # High availability configuration
  ha_enabled    => true,
  ha_role       => 'replica',
  cluster_nodes => [
    '192.168.1.10',  # Primary node IP
    '192.168.1.11',  # Replica node IP
  ],

  # Keepalived VIP configuration
  keepalived_enabled => true,
  vip_address        => '192.168.1.100',        # Same VIP as primary
  vip_address_v6     => 'fd00:1234:5678:1::10/64',  # IPv6 VIP (optional)
  vip_interface      => 'eth0',
  vrrp_priority      => 100,                     # Lower priority = backup
  vrrp_router_id     => 51,                      # Same router ID as primary
  vrrp_auth_pass     => Sensitive('SecureVRRPPassword123!'),

  # Health check settings
  health_check_interval => 2,
  health_check_timeout  => 5,

  # Configuration synchronization
  sync_enabled    => true,
  sync_origin_url => 'http://192.168.1.10:3000',  # Primary node URL
  sync_username   => 'admin',
  sync_password   => Sensitive('AdminPassword123!'),
  sync_interval   => 600,                          # Sync every 10 minutes
  sync_run_on_start => true,                       # Sync immediately on start
  sync_api_enabled  => true,
  sync_api_port     => 8080,

  # Features to synchronize from primary
  sync_features => [
    'general_settings',
    'query_log_config',
    'stats_config',
    'client_settings',
    'services',
    'filters',
    'dhcp_server_config',
    'dns_config',
  ],

  # DNS and web interface settings (same as primary)
  bind_host => '0.0.0.0',
  bind_port => 3000,
  dns_port  => 53,

  # Upstream DNS servers (will be overridden by sync)
  upstream_dns => [
    '1.1.1.1',
    '1.0.0.1',
    '2606:4700:4700::1111',
    '2606:4700:4700::1001',
  ],

  # Enable DNSSEC and filtering
  enable_dnssec    => true,
  enable_filtering => true,

  # Manage firewall rules for DNS, web UI, VRRP, and sync API
  manage_firewall => true,

  # Custom AdGuard configuration (will be overridden by sync)
  adguard_config => {
    'dns' => {
      'ratelimit'            => 30,
      'blocked_response_ttl' => 10,
      'cache_size'           => 8388608,  # 8MB cache
    },
    'filtering' => {
      'protection_enabled' => true,
      'filtering_enabled'  => true,
    },
  },
}
