# frozen_string_literal: true

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
          expect(config['dns']['enable_dnssec']).to eq(true)
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
          expect(config['dns']['enable_dnssec']).to eq(false)
          expect(config['filtering']['enabled']).to eq(false)
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
          expect(config['querylog']['enabled']).to eq(false)
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
