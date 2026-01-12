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
