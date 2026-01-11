# frozen_string_literal: true

require 'spec_helper'

describe 'ha_adguard::install' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }
      let(:pre_condition) { 'include ha_adguard' }

      context 'with ensure => present' do
        it { is_expected.to compile.with_all_deps }

        # Determine expected architecture
        expected_arch = case os_facts[:os][:architecture]
                        when 'x86_64', 'amd64'
                          'amd64'
                        when 'aarch64'
                          'arm64'
                        when 'armv7l'
                          'armv7'
                        end

        it do
          is_expected.to contain_archive('/tmp/AdGuardHome.tar.gz').with(
            ensure: 'present',
            extract: true,
            extract_path: '/opt',
            creates: '/opt/AdGuardHome/AdGuardHome',
            cleanup: true,
            user: 'root',
            group: 'root',
          )
        end

        it do
          is_expected.to contain_file('/opt/AdGuardHome').with(
            ensure: 'directory',
            owner: 'adguard',
            group: 'adguard',
            mode: '0755',
            recurse: true,
          ).that_requires(['Archive[/tmp/AdGuardHome.tar.gz]', 'User[adguard]'])
        end

        it do
          is_expected.to contain_exec('set_adguardhome_capabilities').with(
            command: "setcap 'CAP_NET_BIND_SERVICE=+eip CAP_NET_RAW=+eip' /opt/AdGuardHome/AdGuardHome",
            path: ['/usr/bin', '/usr/sbin', '/bin', '/sbin'],
          ).that_requires('File[/opt/AdGuardHome]')
        end

        it do
          is_expected.to contain_file('/usr/local/bin/adguardhome').with(
            ensure: 'link',
            target: '/opt/AdGuardHome/AdGuardHome',
          ).that_requires('File[/opt/AdGuardHome]')
        end
      end

      context 'with sync enabled' do
        let(:pre_condition) do
          <<-PUPPET
          class { 'ha_adguard':
            sync_enabled => true,
          }
          PUPPET
        end

        it { is_expected.to compile.with_all_deps }

        it do
          is_expected.to contain_archive('/tmp/adguardhome-sync').with(
            ensure: 'present',
            creates: '/usr/local/bin/adguardhome-sync',
            cleanup: true,
          )
        end

        it do
          is_expected.to contain_file('/usr/local/bin/adguardhome-sync').with(
            ensure: 'file',
            owner: 'root',
            group: 'root',
            mode: '0755',
          ).that_requires('Archive[/tmp/adguardhome-sync]')
        end
      end

      context 'with ensure => absent' do
        let(:pre_condition) { "class { 'ha_adguard': ensure => 'absent' }" }

        it { is_expected.to compile.with_all_deps }

        it do
          is_expected.to contain_file('/usr/local/bin/adguardhome').with(
            ensure: 'absent',
          )
        end

        it do
          is_expected.to contain_file('/usr/local/bin/adguardhome-sync').with(
            ensure: 'absent',
          )
        end

        it do
          is_expected.to contain_file('/opt/AdGuardHome').with(
            ensure: 'absent',
            force: true,
            recurse: true,
          )
        end
      end

      context 'with custom install directory' do
        let(:pre_condition) do
          <<-PUPPET
          class { 'ha_adguard':
            install_dir => '/custom/adguard',
          }
          PUPPET
        end

        it do
          is_expected.to contain_file('/custom/adguard').with(
            ensure: 'directory',
          )
        end

        it do
          is_expected.to contain_exec('set_adguardhome_capabilities').with(
            command: "setcap 'CAP_NET_BIND_SERVICE=+eip CAP_NET_RAW=+eip' /custom/adguard/AdGuardHome",
          )
        end
      end
    end
  end

  context 'on unsupported architecture' do
    let(:facts) do
      {
        os: {
          family: 'Debian',
          architecture: 'sparc',
        },
        kernel: 'Linux',
      }
    end
    let(:pre_condition) { 'include ha_adguard' }

    it { is_expected.to compile.and_raise_error(%r{Unsupported architecture}) }
  end

  context 'on unsupported kernel' do
    let(:facts) do
      {
        os: {
          family: 'Debian',
          architecture: 'x86_64',
        },
        kernel: 'Windows',
      }
    end
    let(:pre_condition) { 'include ha_adguard' }

    it { is_expected.to compile.and_raise_error(%r{Unsupported kernel}) }
  end
end
