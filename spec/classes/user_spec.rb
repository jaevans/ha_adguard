# frozen_string_literal: true

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

require 'spec_helper'

describe 'ha_adguard::user' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }
      let(:pre_condition) { 'include ha_adguard' }

      context 'with ensure => present' do
        it { is_expected.to compile.with_all_deps }

        it do
          is_expected.to contain_group('adguard').with(
            ensure: 'present',
            system: true
          )
        end

        it do
          is_expected.to contain_user('adguard').with(
            ensure: 'present',
            system: true,
            shell: '/usr/sbin/nologin',
            home: '/var/lib/adguardhome',
            comment: 'AdGuard Home service user',
            managehome: false
          ).that_requires('Group[adguard]')
        end

        it do
          is_expected.to contain_file('/var/lib/adguardhome').with(
            ensure: 'directory',
            owner: 'adguard',
            group: 'adguard',
            mode: '0750'
          ).that_requires('User[adguard]')
        end
      end

      context 'with custom user and group' do
        let(:pre_condition) do
          <<-PUPPET
          class { 'ha_adguard':
            user  => 'customuser',
            group => 'customgroup',
            uid   => 5000,
            gid   => 5000,
          }
          PUPPET
        end

        it do
          is_expected.to contain_group('customgroup').with(
            ensure: 'present',
            gid: 5000,
            system: true
          )
        end

        it do
          is_expected.to contain_user('customuser').with(
            ensure: 'present',
            uid: 5000,
            gid: 'customgroup',
            system: true
          )
        end
      end

      context 'with ensure => absent' do
        let(:pre_condition) { "class { 'ha_adguard': ensure => 'absent' }" }

        it { is_expected.to compile.with_all_deps }

        it do
          is_expected.to contain_file('/var/lib/adguardhome').with(
            ensure: 'absent',
            force: true,
            recurse: true
          )
        end

        it do
          is_expected.to contain_user('adguard').with(
            ensure: 'absent'
          ).that_requires('File[/var/lib/adguardhome]')
        end

        it do
          is_expected.to contain_group('adguard').with(
            ensure: 'absent'
          ).that_requires('User[adguard]')
        end
      end
    end
  end
end
