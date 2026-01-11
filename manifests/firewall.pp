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
