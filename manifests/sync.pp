# @summary Manages adguardhome-sync for configuration replication
#
# @api private
#
class ha_adguard::sync {
  if $ha_adguard::ensure == 'present' and $ha_adguard::sync_enabled and $ha_adguard::ha_role == 'replica' {
    # Create sync config directory
    file { '/etc/adguardhome-sync':
      ensure => directory,
      owner  => 'root',
      group  => 'root',
      mode   => '0750',
    }

    # Create sync configuration file
    file { '/etc/adguardhome-sync/config.yaml':
      ensure  => file,
      owner   => 'root',
      group   => 'root',
      mode    => '0600',
      content => epp('ha_adguard/sync_config.yaml.epp', {
          'origin_url'    => $ha_adguard::sync_origin_url,
          'username'      => $ha_adguard::sync_username,
          'password'      => $ha_adguard::sync_password,
          'replica_url'   => "http://127.0.0.1:${ha_adguard::bind_port}",
          'interval'      => $ha_adguard::sync_interval,
          'run_on_start'  => $ha_adguard::sync_run_on_start,
          'api_enabled'   => $ha_adguard::sync_api_enabled,
          'api_port'      => $ha_adguard::sync_api_port,
          'sync_features' => $ha_adguard::sync_features,
      }),
      require => File['/etc/adguardhome-sync'],
    }

    # Create systemd unit file using puppet/systemd module
    systemd::unit_file { 'adguardhome-sync.service':
      content => epp('ha_adguard/sync.service.epp'),
      enable  => true,
      active  => true,
    }

    # Manage sync service
    service { 'adguardhome-sync':
      ensure    => running,
      enable    => true,
      subscribe => File['/etc/adguardhome-sync/config.yaml'],
      require   => [
        Systemd::Unit_file['adguardhome-sync.service'],
        Service['adguardhome'],
      ],
    }
  } elsif $ha_adguard::ensure == 'absent' and $ha_adguard::sync_enabled {
    # Stop sync service
    service { 'adguardhome-sync':
      ensure => stopped,
      enable => false,
      before => Systemd::Unit_file['adguardhome-sync.service'],
    }

    # Remove systemd unit file
    systemd::unit_file { 'adguardhome-sync.service':
      ensure => absent,
    }

    # Remove sync configuration
    file { '/etc/adguardhome-sync':
      ensure  => absent,
      force   => true,
      recurse => true,
    }
  }
}
