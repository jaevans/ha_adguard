# High-availability AdGuard Home - Primary Node
#
# This example demonstrates a primary node in an HA cluster with:
# - Keepalived for VIP failover
# - Higher VRRP priority (becomes master)
# - Health checks for VRRP
# - Firewall management
#
# Usage:
#   puppet apply examples/ha_primary.pp

class { 'ha_adguard':
  ensure => present,

  # High availability configuration
  ha_enabled    => true,
  ha_role       => 'primary',
  cluster_nodes => [
    '192.168.1.10',  # Primary node IP
    '192.168.1.11',  # Replica node IP
  ],

  # Keepalived VIP configuration
  keepalived_enabled => true,
  vip_address        => '192.168.1.100',        # Floating IP for DNS service
  vip_interface      => 'eth0',
  vrrp_priority      => 150,                     # Higher priority = master
  vrrp_router_id     => 51,
  vrrp_auth_pass     => Sensitive('SecureVRRPPassword123!'),

  # Health check settings
  health_check_interval => 2,
  health_check_timeout  => 5,

  # DNS and web interface settings
  bind_host => '0.0.0.0',
  bind_port => 3000,
  dns_port  => 53,

  # Upstream DNS servers
  upstream_dns => [
    '1.1.1.1',
    '1.0.0.1',
    '2606:4700:4700::1111',
    '2606:4700:4700::1001',
  ],

  # Enable DNSSEC and filtering
  enable_dnssec    => true,
  enable_filtering => true,

  # AdGuard admin credentials (needed for sync from replica)
  sync_username => 'admin',
  sync_password => Sensitive('AdminPassword123!'),

  # Manage firewall rules for DNS, web UI, and VRRP
  manage_firewall => true,

  # Custom AdGuard configuration
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
