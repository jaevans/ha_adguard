# Single-node AdGuard Home installation
#
# This example demonstrates a basic single-node installation of AdGuard Home
# with custom DNS settings and firewall management.
#
# Usage:
#   puppet apply examples/single_node.pp

class { 'ha_adguard':
  ensure       => present,
  bind_host    => '0.0.0.0',
  bind_port    => 3000,
  dns_port     => 53,

  # Use Cloudflare and Google DNS as upstream servers
  upstream_dns => [
    '1.1.1.1',
    '1.0.0.1',
    '8.8.8.8',
    '8.8.4.4',
  ],

  # Enable DNSSEC validation and ad filtering
  enable_dnssec    => true,
  enable_filtering => true,

  # Manage firewall rules automatically
  manage_firewall => true,

  # Custom configuration via deep merge
  adguard_config => {
    'dns' => {
      'ratelimit'            => 20,
      'blocked_response_ttl' => 10,
      'cache_size'           => 4194304,
    },
    'filtering' => {
      'protection_enabled' => true,
      'filtering_enabled'  => true,
    },
  },
}
