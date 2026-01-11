# @summary Manages the AdGuard Home system user and group
#
# @api private
#
class ha_adguard::user {
  if $ha_adguard::ensure == 'present' {
    group { $ha_adguard::group:
      ensure => present,
      gid    => $ha_adguard::gid,
      system => true,
    }

    user { $ha_adguard::user:
      ensure     => present,
      uid        => $ha_adguard::uid,
      gid        => $ha_adguard::group,
      system     => true,
      shell      => '/usr/sbin/nologin',
      home       => $ha_adguard::work_dir,
      comment    => 'AdGuard Home service user',
      managehome => false,
      require    => Group[$ha_adguard::group],
    }

    file { $ha_adguard::work_dir:
      ensure  => directory,
      owner   => $ha_adguard::user,
      group   => $ha_adguard::group,
      mode    => '0750',
      require => User[$ha_adguard::user],
    }
  } else {
    file { $ha_adguard::work_dir:
      ensure  => absent,
      force   => true,
      recurse => true,
    }

    user { $ha_adguard::user:
      ensure  => absent,
      require => File[$ha_adguard::work_dir],
    }

    group { $ha_adguard::group:
      ensure  => absent,
      require => User[$ha_adguard::user],
    }
  }
}
