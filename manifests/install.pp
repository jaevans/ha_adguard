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
      unless  => "getcap ${ha_adguard::install_dir}/AdGuardHome | grep -qE 'cap_net_bind_service.*cap_net_raw'",
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
      $sync_archive = "adguardhome-sync_${ha_adguard::sync_version}_${os_type}_${arch}.tar.gz"
      $sync_url = "https://github.com/bakito/adguardhome-sync/releases/download/v${ha_adguard::sync_version}/${sync_archive}"

      archive { '/tmp/adguardhome-sync.tar.gz':
        ensure       => present,
        source       => $sync_url,
        extract      => true,
        extract_path => '/tmp',
        creates      => '/tmp/adguardhome-sync',
        cleanup      => true,
      }

      file { '/usr/local/bin/adguardhome-sync':
        ensure  => file,
        owner   => 'root',
        group   => 'root',
        mode    => '0755',
        source  => '/tmp/adguardhome-sync',
        require => Archive['/tmp/adguardhome-sync.tar.gz'],
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
