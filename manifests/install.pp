# @summary Installs AdGuard Home and adguardhome-sync binaries
#
# @api private
#
class ha_adguard::install {
  # Determine architecture
  $arch = $facts['os']['architecture'] ? {
    'x86_64' => 'amd64',
    'amd64'  => 'amd64',
    'aarch64' => 'arm64',
    'armv7l'  => 'armv7',
    default   => fail("Unsupported architecture: ${facts['os']['architecture']}"),
  }

  # Determine OS type
  $os_type = $facts['kernel'] ? {
    'Linux'  => 'linux',
    default  => fail("Unsupported kernel: ${facts['kernel']}"),
  }

  if $ha_adguard::ensure == 'present' {
    # AdGuard Home installation
    $adguard_archive = "AdGuardHome_${os_type}_${arch}.tar.gz"
    $adguard_url = "${ha_adguard::adguard_download_url}/v${ha_adguard::adguard_version}/${adguard_archive}"
    $adguard_extract_path = dirname($ha_adguard::install_dir)

    archive { '/tmp/AdGuardHome.tar.gz':
      ensure       => present,
      source       => $adguard_url,
      extract      => true,
      extract_path => $adguard_extract_path,
      creates      => "${ha_adguard::install_dir}/AdGuardHome",
      cleanup      => true,
      user         => 'root',
      group        => 'root',
    }

    file { $ha_adguard::install_dir:
      ensure  => directory,
      owner   => $ha_adguard::user,
      group   => $ha_adguard::group,
      mode    => '0755',
      recurse => true,
      require => [
        Archive['/tmp/AdGuardHome.tar.gz'],
        User[$ha_adguard::user],
      ],
    }

    # Set capabilities for binding to privileged ports
    exec { 'set_adguardhome_capabilities':
      command => "setcap 'CAP_NET_BIND_SERVICE=+eip CAP_NET_RAW=+eip' ${ha_adguard::install_dir}/AdGuardHome",
      path    => ['/usr/bin', '/usr/sbin', '/bin', '/sbin'],
      unless  => "getcap ${ha_adguard::install_dir}/AdGuardHome | grep -q 'cap_net_bind_service,cap_net_raw+eip'",
      require => File[$ha_adguard::install_dir],
    }

    # Create symlink
    file { '/usr/local/bin/adguardhome':
      ensure  => link,
      target  => "${ha_adguard::install_dir}/AdGuardHome",
      require => File[$ha_adguard::install_dir],
    }

    # Install adguardhome-sync if sync is enabled
    if $ha_adguard::sync_enabled {
      $sync_binary = "adguardhome-sync_${ha_adguard::sync_version}_${os_type}_${arch}"
      $sync_url = "https://github.com/bakito/adguardhome-sync/releases/download/v${ha_adguard::sync_version}/${sync_binary}"

      archive { '/tmp/adguardhome-sync':
        ensure  => present,
        source  => $sync_url,
        creates => '/usr/local/bin/adguardhome-sync',
        cleanup => true,
      }

      file { '/usr/local/bin/adguardhome-sync':
        ensure  => file,
        owner   => 'root',
        group   => 'root',
        mode    => '0755',
        source  => '/tmp/adguardhome-sync',
        require => Archive['/tmp/adguardhome-sync'],
      }
    }
  } else {
    # Removal
    file { '/usr/local/bin/adguardhome':
      ensure => absent,
    }

    file { '/usr/local/bin/adguardhome-sync':
      ensure => absent,
    }

    file { $ha_adguard::install_dir:
      ensure  => absent,
      force   => true,
      recurse => true,
    }
  }
}
