# frozen_string_literal: true

require 'spec_helper'

describe 'ha_adguard::sync' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      context 'with sync disabled' do
        let(:pre_condition) { 'include ha_adguard' }

        it { is_expected.to compile.with_all_deps }
        it { is_expected.not_to contain_file('/etc/adguardhome-sync') }
        it { is_expected.not_to contain_systemd__unit_file('adguardhome-sync.service') }
        it { is_expected.not_to contain_service('adguardhome-sync') }
      end

      context 'with sync enabled on primary' do
        let(:pre_condition) do
          <<-PUPPET
          class { 'ha_adguard':
            ha_role      => 'primary',
            sync_enabled => true,
          }
          PUPPET
        end

        it { is_expected.to compile.with_all_deps }
        it { is_expected.not_to contain_file('/etc/adguardhome-sync') }
      end

      context 'with sync enabled on replica' do
        let(:pre_condition) do
          <<-PUPPET
          class { 'ha_adguard':
            ha_role         => 'replica',
            sync_enabled    => true,
            sync_origin_url => 'http://primary.example.com:3000',
            sync_password   => Sensitive('supersecret'),
          }
          PUPPET
        end

        it { is_expected.to compile.with_all_deps }

        it do
          is_expected.to contain_file('/etc/adguardhome-sync').with(
            ensure: 'directory',
            owner: 'root',
            group: 'root',
            mode: '0750',
          )
        end

        it do
          is_expected.to contain_file('/etc/adguardhome-sync/config.yaml').with(
            ensure: 'file',
            owner: 'root',
            group: 'root',
            mode: '0600',
          ).that_requires('File[/etc/adguardhome-sync]')
        end

        it 'generates valid sync config' do
          content = catalogue.resource('file', '/etc/adguardhome-sync/config.yaml')[:content]
          config = YAML.safe_load(content)
          expect(config['origin']['url']).to eq('http://primary.example.com:3000')
          expect(config['origin']['username']).to eq('admin')
          expect(config['origin']['password']).to eq('supersecret')
          expect(config['replicas']).to be_a(Array)
          expect(config['replicas'].first['url']).to eq('http://127.0.0.1:3000')
        end

        it 'includes sync features' do
          content = catalogue.resource('file', '/etc/adguardhome-sync/config.yaml')[:content]
          config = YAML.safe_load(content)
          expect(config['features']['general_settings']).to eq(true)
          expect(config['features']['dns_config']).to eq(true)
          expect(config['features']['filters']).to eq(true)
        end

        it do
          is_expected.to contain_systemd__unit_file('adguardhome-sync.service').with(
            enable: true,
            active: true,
          )
        end

        it 'generates valid systemd unit' do
          content = catalogue.resource('systemd::unit_file', 'adguardhome-sync.service')[:content]
          expect(content).to match(%r{Description=AdGuard Home Sync Service})
          expect(content).to match(%r{After=.*adguardhome.service})
          expect(content).to match(%r{Requires=adguardhome.service})
          expect(content).to match(%r{ExecStart=/usr/local/bin/adguardhome-sync run})
          expect(content).to match(%r{--config /etc/adguardhome-sync/config.yaml})
        end

        it do
          is_expected.to contain_service('adguardhome-sync').with(
            ensure: 'running',
            enable: true,
          ).that_requires([
            'Systemd::Unit_file[adguardhome-sync.service]',
            'Service[adguardhome]',
          ])
        end

        it 'service subscribes to config changes' do
          is_expected.to contain_service('adguardhome-sync').that_subscribes_to(
            'File[/etc/adguardhome-sync/config.yaml]',
          )
        end
      end

      context 'with custom sync configuration' do
        let(:pre_condition) do
          <<-PUPPET
          class { 'ha_adguard':
            ha_role            => 'replica',
            sync_enabled       => true,
            sync_origin_url    => 'http://primary.example.com:8080',
            sync_username      => 'syncuser',
            sync_password      => Sensitive('test123'),
            sync_interval      => 300,
            sync_run_on_start  => false,
            sync_api_enabled   => false,
            sync_api_port      => 9090,
            bind_port          => 8080,
          }
          PUPPET
        end

        it 'uses custom sync configuration' do
          content = catalogue.resource('file', '/etc/adguardhome-sync/config.yaml')[:content]
          config = YAML.safe_load(content)
          expect(config['origin']['url']).to eq('http://primary.example.com:8080')
          expect(config['origin']['username']).to eq('syncuser')
          expect(config['origin']['password']).to eq('test123')
          expect(config['replicas'].first['url']).to eq('http://127.0.0.1:8080')
          expect(config['runOnStart']).to eq(false)
          expect(config['api']['enabled']).to eq(false)
          expect(config['api']['port']).to eq(9090)
        end
      end

      context 'with custom sync features' do
        let(:pre_condition) do
          <<-PUPPET
          class { 'ha_adguard':
            ha_role         => 'replica',
            sync_enabled    => true,
            sync_origin_url => 'http://primary.example.com:3000',
            sync_features   => ['general_settings', 'filters'],
          }
          PUPPET
        end

        it 'uses custom sync features' do
          content = catalogue.resource('file', '/etc/adguardhome-sync/config.yaml')[:content]
          config = YAML.safe_load(content)
          expect(config['features']['general_settings']).to eq(true)
          expect(config['features']['filters']).to eq(true)
          expect(config['features'].keys).to contain_exactly('general_settings', 'filters')
        end
      end

      context 'with ensure => absent and sync enabled' do
        let(:pre_condition) do
          <<-PUPPET
          class { 'ha_adguard':
            ensure          => 'absent',
            ha_role         => 'replica',
            sync_enabled    => true,
            sync_origin_url => 'http://primary.example.com:3000',
          }
          PUPPET
        end

        it { is_expected.to compile.with_all_deps }

        it do
          is_expected.to contain_service('adguardhome-sync').with(
            ensure: 'stopped',
            enable: false,
          ).that_comes_before('Systemd::Unit_file[adguardhome-sync.service]')
        end

        it do
          is_expected.to contain_systemd__unit_file('adguardhome-sync.service').with(
            ensure: 'absent',
          )
        end

        it do
          is_expected.to contain_file('/etc/adguardhome-sync').with(
            ensure: 'absent',
            force: true,
            recurse: true,
          )
        end
      end
    end
  end
end
