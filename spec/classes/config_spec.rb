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

describe 'ha_adguard::config' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }
      let(:pre_condition) { 'include ha_adguard' }

      context 'with ensure => present' do
        it { is_expected.to compile.with_all_deps }

        it do
          is_expected.to contain_file('/etc/adguardhome').with(
            ensure: 'directory',
            owner: 'adguard',
            group: 'adguard',
            mode: '0750',
          )
        end

        it do
          is_expected.to contain_file('/etc/adguardhome/AdGuardHome.yaml').with(
            ensure: 'file',
            owner: 'adguard',
            group: 'adguard',
            mode: '0600',
          ).that_requires('File[/etc/adguardhome]')
        end

        it 'generates valid YAML configuration' do
          content = catalogue.resource('file', '/etc/adguardhome/AdGuardHome.yaml')[:content]
          expect { YAML.safe_load(content) }.not_to raise_error
        end

        it 'includes default DNS configuration' do
          content = catalogue.resource('file', '/etc/adguardhome/AdGuardHome.yaml')[:content]
          config = YAML.safe_load(content)
          expect(config['bind_host']).to eq('0.0.0.0')
          expect(config['bind_port']).to eq(3000)
          expect(config['dns']['port']).to eq(53)
          expect(config['dns']['enable_dnssec']).to be(true)
        end

        it 'includes upstream DNS servers' do
          content = catalogue.resource('file', '/etc/adguardhome/AdGuardHome.yaml')[:content]
          config = YAML.safe_load(content)
          expect(config['dns']['upstream_dns']).to include('1.1.1.1', '8.8.8.8')
        end
      end

      context 'with custom DNS configuration' do
        let(:pre_condition) do
          <<-PUPPET
          class { 'ha_adguard':
            bind_host       => '127.0.0.1',
            bind_port       => 8080,
            dns_port        => 5353,
            upstream_dns    => ['9.9.9.9', '1.1.1.1'],
            enable_dnssec   => false,
            enable_filtering => false,
          }
          PUPPET
        end

        it do
          content = catalogue.resource('file', '/etc/adguardhome/AdGuardHome.yaml')[:content]
          config = YAML.safe_load(content)
          expect(config['bind_host']).to eq('127.0.0.1')
          expect(config['bind_port']).to eq(8080)
          expect(config['dns']['port']).to eq(5353)
          expect(config['dns']['upstream_dns']).to eq(['9.9.9.9', '1.1.1.1'])
          expect(config['dns']['enable_dnssec']).to be(false)
          expect(config['filtering']['enabled']).to be(false)
        end
      end

      # AdGuard Home's schema-23 migration moved bind_host/bind_port under
      # http.address. At schema_version 28 that migration never runs, so
      # top-level bind_host/bind_port are silently ignored and the web UI
      # falls back to its default address.
      context 'with a custom web address at the declared schema version' do
        let(:pre_condition) do
          <<-PUPPET
          class { 'ha_adguard':
            bind_host => '127.0.0.1',
            bind_port => 8080,
          }
          PUPPET
        end

        it 'writes the address where AdGuard Home reads it' do
          config = YAML.safe_load(catalogue.resource('file', '/etc/adguardhome/AdGuardHome.yaml')[:content])
          expect(config['schema_version']).to be >= 23
          expect(config.dig('http', 'address')).to eq('127.0.0.1:8080')
          expect(config).not_to include('bind_host', 'bind_port')
        end
      end

      context 'with an IPv6 VIP' do
        let(:pre_condition) do
          <<-PUPPET
          class { 'ha_adguard':
            keepalived_enabled => true,
            vip_address        => '192.168.255.10',
            vip_address_v6     => 'fd00::53/64',
          }
          PUPPET
        end

        it 'binds DNS on an IPv6 address' do
          config = YAML.safe_load(catalogue.resource('file', '/etc/adguardhome/AdGuardHome.yaml')[:content])
          expect(config['dns']['bind_hosts']).to include(a_string_including(':'))
        end
      end

      context 'with custom config hash' do
        let(:pre_condition) do
          <<-PUPPET
          class { 'ha_adguard':
            adguard_config => {
              'dns' => {
                'cache_size' => 8388608,
              },
              'querylog' => {
                'enabled' => false,
              },
            },
          }
          PUPPET
        end

        it 'deep merges custom config with defaults' do
          content = catalogue.resource('file', '/etc/adguardhome/AdGuardHome.yaml')[:content]
          config = YAML.safe_load(content)
          # Custom values should be present
          expect(config['dns']['cache_size']).to eq(8_388_608)
          expect(config['querylog']['enabled']).to be(false)
          # Default values should still be present
          expect(config['dns']['port']).to eq(53)
          expect(config['bind_port']).to eq(3000)
        end
      end

      context 'with ensure => absent' do
        let(:pre_condition) { "class { 'ha_adguard': ensure => 'absent' }" }

        it { is_expected.to compile.with_all_deps }

        it do
          is_expected.to contain_file('/etc/adguardhome').with(
            ensure: 'absent',
            force: true,
            recurse: true,
          )
        end
      end

      context 'with custom config directory' do
        let(:pre_condition) do
          <<-PUPPET
          class { 'ha_adguard':
            config_dir => '/custom/config',
          }
          PUPPET
        end

        it do
          is_expected.to contain_file('/custom/config').with(
            ensure: 'directory',
          )
        end

        it do
          is_expected.to contain_file('/custom/config/AdGuardHome.yaml').with(
            ensure: 'file',
          )
        end
      end
    end
  end
end
