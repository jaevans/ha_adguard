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
