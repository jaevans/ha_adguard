# @summary Manages AdGuard Home systemd service
#
# @api private
#
class ha_adguard::service {
  if $ha_adguard::ensure == 'present' and $ha_adguard::manage_service {
    # Create systemd unit file using puppet/systemd module
    systemd::unit_file { 'adguardhome.service':
      content => epp('ha_adguard/adguardhome.service.epp', {
          'install_dir' => $ha_adguard::install_dir,
          'config_dir'  => $ha_adguard::config_dir,
          'work_dir'    => $ha_adguard::work_dir,
          'user'        => $ha_adguard::user,
          'group'       => $ha_adguard::group,
      }),
      enable  => $ha_adguard::service_enable,
      active  => $ha_adguard::service_ensure == 'running',
    }

    # Manage service state
    service { 'adguardhome':
      ensure    => $ha_adguard::service_ensure,
      enable    => $ha_adguard::service_enable,
      subscribe => [
        File["${ha_adguard::config_dir}/AdGuardHome.yaml"],
        Systemd::Unit_file['adguardhome.service'],
      ],
      require   => Systemd::Unit_file['adguardhome.service'],
    }
  } elsif $ha_adguard::ensure == 'absent' {
    # Stop and disable service
    service { 'adguardhome':
      ensure => stopped,
      enable => false,
      before => Systemd::Unit_file['adguardhome.service'],
    }

    # Remove systemd unit file
    systemd::unit_file { 'adguardhome.service':
      ensure => absent,
    }
  }
}
