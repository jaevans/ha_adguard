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
# @summary Manages firewall rules for AdGuard Home
#
# @api private
#
class ha_adguard::firewall {
  if $ha_adguard::ensure == 'present' and $ha_adguard::manage_firewall {
    # Allow DNS over TCP
    firewall { '100 allow DNS tcp':
      dport => $ha_adguard::dns_port,
      proto => 'tcp',
      jump  => 'accept',
    }

    # Allow DNS over UDP
    firewall { '100 allow DNS udp':
      dport => $ha_adguard::dns_port,
      proto => 'udp',
      jump  => 'accept',
    }

    # Allow AdGuard Home web UI
    firewall { '100 allow AdGuard web UI':
      dport => $ha_adguard::bind_port,
      proto => 'tcp',
      jump  => 'accept',
    }

    # Allow VRRP for keepalived if enabled
    if $ha_adguard::keepalived_enabled {
      firewall { '100 allow VRRP':
        proto => 'vrrp',
        jump  => 'accept',
      }
    }

    # Allow sync API if enabled
    if $ha_adguard::sync_enabled and $ha_adguard::sync_api_enabled {
      firewall { '100 allow adguardhome-sync API':
        dport => $ha_adguard::sync_api_port,
        proto => 'tcp',
        jump  => 'accept',
      }
    }
  } elsif $ha_adguard::ensure == 'absent' and $ha_adguard::manage_firewall {
    # Remove DNS rules
    firewall { '100 allow DNS tcp':
      ensure => absent,
    }

    firewall { '100 allow DNS udp':
      ensure => absent,
    }

    # Remove web UI rule
    firewall { '100 allow AdGuard web UI':
      ensure => absent,
    }

    # Remove VRRP rule if it exists
    if $ha_adguard::keepalived_enabled {
      firewall { '100 allow VRRP':
        ensure => absent,
      }
    }

    # Remove sync API rule if it exists
    if $ha_adguard::sync_enabled and $ha_adguard::sync_api_enabled {
      firewall { '100 allow adguardhome-sync API':
        ensure => absent,
      }
    }
  }
}
