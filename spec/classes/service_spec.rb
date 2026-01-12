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

describe 'ha_adguard::service' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }
      let(:pre_condition) { 'include ha_adguard' }

      context 'with ensure => present and manage_service => true' do
        it { is_expected.to compile.with_all_deps }

        it do
          is_expected.to contain_systemd__unit_file('adguardhome.service').with(
            enable: true,
            active: true
          )
        end

        it 'generates valid systemd unit content' do
          content = catalogue.resource('systemd::unit_file', 'adguardhome.service')[:content]
          expect(content).to match(%r{\[Unit\]})
          expect(content).to match(%r{Description=AdGuard Home DNS server})
          expect(content).to match(%r{After=network-online.target})
          expect(content).to match(%r{\[Service\]})
          expect(content).to match(%r{User=adguard})
          expect(content).to match(%r{ExecStart=/opt/AdGuardHome/AdGuardHome})
          expect(content).to match(%r{--config /etc/adguardhome/AdGuardHome.yaml})
          expect(content).to match(%r{--work-dir /var/lib/adguardhome})
          expect(content).to match(%r{CAP_NET_BIND_SERVICE})
          expect(content).to match(%r{CAP_NET_RAW})
        end

        it do
          is_expected.to contain_service('adguardhome').with(
            ensure: 'running',
            enable: true
          ).that_requires('Systemd::Unit_file[adguardhome.service]')
        end

        it 'service subscribes to config changes' do
          is_expected.to contain_service('adguardhome').that_subscribes_to(
            'File[/etc/adguardhome/AdGuardHome.yaml]'
          )
        end
      end

      context 'with service_ensure => stopped' do
        let(:pre_condition) do
          <<-PUPPET
          class { 'ha_adguard':
            service_ensure => 'stopped',
          }
          PUPPET
        end

        it do
          is_expected.to contain_service('adguardhome').with(
            ensure: 'stopped'
          )
        end
      end

      context 'with service_enable => false' do
        let(:pre_condition) do
          <<-PUPPET
          class { 'ha_adguard':
            service_enable => false,
          }
          PUPPET
        end

        it do
          is_expected.to contain_service('adguardhome').with(
            enable: false
          )
        end

        it do
          is_expected.to contain_systemd__unit_file('adguardhome.service').with(
            enable: false
          )
        end
      end

      context 'with manage_service => false' do
        let(:pre_condition) do
          <<-PUPPET
          class { 'ha_adguard':
            manage_service => false,
          }
          PUPPET
        end

        it { is_expected.to compile.with_all_deps }
        it { is_expected.not_to contain_systemd__unit_file('adguardhome.service') }
        it { is_expected.not_to contain_service('adguardhome') }
      end

      context 'with ensure => absent' do
        let(:pre_condition) { "class { 'ha_adguard': ensure => 'absent' }" }

        it { is_expected.to compile.with_all_deps }

        it do
          is_expected.to contain_service('adguardhome').with(
            ensure: 'stopped',
            enable: false
          ).that_comes_before('Systemd::Unit_file[adguardhome.service]')
        end

        it do
          is_expected.to contain_systemd__unit_file('adguardhome.service').with(
            ensure: 'absent'
          )
        end
      end

      context 'with custom paths' do
        let(:pre_condition) do
          <<-PUPPET
          class { 'ha_adguard':
            install_dir => '/custom/adguard',
            config_dir  => '/custom/config',
            work_dir    => '/custom/work',
          }
          PUPPET
        end

        it 'uses custom paths in systemd unit' do
          content = catalogue.resource('systemd::unit_file', 'adguardhome.service')[:content]
          expect(content).to match(%r{ExecStart=/custom/adguard/AdGuardHome})
          expect(content).to match(%r{--config /custom/config/AdGuardHome.yaml})
          expect(content).to match(%r{--work-dir /custom/work})
        end
      end

      context 'with custom user and group' do
        let(:pre_condition) do
          <<-PUPPET
          class { 'ha_adguard':
            user  => 'customuser',
            group => 'customgroup',
          }
          PUPPET
        end

        it 'uses custom user and group in systemd unit' do
          content = catalogue.resource('systemd::unit_file', 'adguardhome.service')[:content]
          expect(content).to match(%r{User=customuser})
          expect(content).to match(%r{Group=customgroup})
        end
      end
    end
  end
end
