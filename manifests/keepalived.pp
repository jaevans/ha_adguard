# @summary Manages Keepalived for VIP failover
#
# @api private
#
class ha_adguard::keepalived {
  if $ha_adguard::ensure == 'present' and $ha_adguard::keepalived_enabled {
    # Include keepalived main class
    class { 'keepalived':
      service_manage => true,
    }

    # Create health check script
    file { '/usr/local/bin/check_adguard.sh':
      ensure  => file,
      owner   => 'root',
      group   => 'root',
      mode    => '0755',
      content => epp('ha_adguard/health_check.sh.epp', {
          'dns_port' => $ha_adguard::dns_port,
      }),
    }

    # Define VRRP health check script
    keepalived::vrrp::script { 'check_adguard':
      script   => '/usr/local/bin/check_adguard.sh',
      interval => $ha_adguard::health_check_interval,
      weight   => -20,
      require  => File['/usr/local/bin/check_adguard.sh'],
    }

    # Define VRRP instance for AdGuard Home
    keepalived::vrrp::instance { 'VI_ADGUARD':
      interface         => $ha_adguard::vrrp_interface,
      state             => 'BACKUP',
      virtual_router_id => $ha_adguard::vrrp_router_id,
      priority          => $ha_adguard::vrrp_priority,
      auth_type         => 'PASS',
      auth_pass         => $ha_adguard::vrrp_auth_pass,
      virtual_ipaddress => [$ha_adguard::vip_address],
      track_script      => ['check_adguard'],
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
