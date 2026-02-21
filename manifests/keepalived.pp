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
# @summary Manages Keepalived for VIP failover
#
# @api private
#
class ha_adguard::keepalived {
  if $ha_adguard::ensure == 'present' and $ha_adguard::keepalived_enabled {
    # Create health check script FIRST, before keepalived validates config
    file { '/usr/local/bin/check_adguard.sh':
      ensure  => file,
      owner   => 'root',
      group   => 'root',
      mode    => '0755',
      content => epp('ha_adguard/health_check.sh.epp', {
        'dns_port' => $ha_adguard::dns_port,
      }),
    }

    # Include keepalived main class after health check script
    class { 'keepalived':
      service_manage => true,
      global_defs    => {
        enable_script_security => true,
        script_user            => 'root',
      },
      require        => File['/usr/local/bin/check_adguard.sh'],
    }

    # Define VRRP health check script
    keepalived::vrrp::script { 'check_adguard':
      script   => '/usr/local/bin/check_adguard.sh',
      interval => $ha_adguard::health_check_interval,
      weight   => -20,
      require  => File['/usr/local/bin/check_adguard.sh'],
    }

    # Define VRRP instance for AdGuard Home
    # Primary nodes start as MASTER to enable automatic failback
    # Replica nodes start as BACKUP
    $vrrp_state = $ha_adguard::ha_role ? {
      'primary' => 'MASTER',
      'replica' => 'BACKUP',
      default   => 'BACKUP',
    }

    keepalived::vrrp::instance { 'VI_ADGUARD':
      interface         => $ha_adguard::vrrp_interface,
      state             => $vrrp_state,
      virtual_router_id => $ha_adguard::vrrp_router_id,
      priority          => $ha_adguard::vrrp_priority,
      auth_type         => 'PASS',
      auth_pass         => $ha_adguard::vrrp_auth_pass,
      virtual_ipaddress => [$ha_adguard::vip_address],
      track_script      => ['check_adguard'],
    }

    if $ha_adguard::vip_address_v6 {
      # IPv6 uses VRRPv3 — no authentication, native_ipv6 required
      keepalived::vrrp::instance { 'VI_ADGUARD6':
        interface         => $ha_adguard::vrrp_interface,
        state             => $vrrp_state,
        virtual_router_id => $ha_adguard::vrrp_router_id,
        priority          => $ha_adguard::vrrp_priority,
        native_ipv6       => true,
        virtual_ipaddress => [$ha_adguard::vip_address_v6],
        track_script      => ['check_adguard'],
      }

      keepalived::vrrp::sync_group { 'VG_ADGUARD':
        group => ['VI_ADGUARD', 'VI_ADGUARD6'],
      }
    }
  } elsif $ha_adguard::ensure == 'absent' {
    # Remove health check script
    file { '/usr/local/bin/check_adguard.sh':
      ensure => absent,
    }

    # Note: keepalived::vrrp::instance and keepalived::vrrp::script resources do not support
    # ensure => absent. The keepalived configuration is managed by the puppet/keepalived module
    # and will be cleaned up when the module is purged from the node.
  }
}
