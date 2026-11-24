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

describe 'ha_adguard::install' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }
      let(:pre_condition) { 'include ha_adguard' }

      context 'with ensure => present' do
        it { is_expected.to compile.with_all_deps }

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

      # Both archives are guarded by version-independent paths, so once a
      # binary exists Puppet never fetches a different version, and nothing
      # restarts the running service after a binary changes.
      context 'with non-default versions' do
        let(:pre_condition) do
          <<-PUPPET
          class { 'ha_adguard':
            adguard_version => '0.107.99',
            sync_version    => '9.9.9',
            ha_role         => 'replica',
            sync_enabled    => true,
            sync_origin_url => 'http://primary.example.com:3000',
          }
          PUPPET
        end

        def archive_for(version)
          catalogue.resources.find { |r| r.type == 'Archive' && r[:source].to_s.include?("v#{version}/") }
        end

        it 'ties the AdGuard Home download guard to the version' do
          archive = archive_for('0.107.99')
          expect("#{archive.title} #{archive[:creates]}").to include('0.107.99')
        end

        it 'ties the adguardhome-sync download guard to the version' do
          archive = archive_for('9.9.9')
          expect("#{archive.title} #{archive[:creates]}").to include('9.9.9')
        end

        it 'verifies both downloads against a checksum' do
          [archive_for('0.107.99'), archive_for('9.9.9')].each do |archive|
            expect(archive[:checksum] || archive[:checksum_url]).not_to be_nil, "#{archive.title} has no checksum"
          end
        end

        it 'restarts AdGuard Home when its archive changes' do
          is_expected.to contain_archive(archive_for('0.107.99').title).that_notifies('Service[adguardhome]')
        end

        it 'restarts adguardhome-sync when its archive changes' do
          is_expected.to contain_archive(archive_for('9.9.9').title).that_notifies('Service[adguardhome-sync]')
        end
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

        it do
          is_expected.to contain_archive('/tmp/adguardhome-sync.tar.gz').with(
            ensure: 'present',
            creates: '/tmp/adguardhome-sync',
            cleanup: true,
          )
        end

        it do
          is_expected.to contain_file('/usr/local/bin/adguardhome-sync').with(
            ensure: 'file',
            owner: 'root',
            group: 'root',
            mode: '0755',
          ).that_requires('Archive[/tmp/adguardhome-sync.tar.gz]')
        end
      end

      context 'with sync enabled on replica' do
        let(:pre_condition) do
          <<-PUPPET
          class { 'ha_adguard':
            ha_role         => 'replica',
            sync_enabled    => true,
            sync_origin_url => 'http://primary.example.com:3000',
          }
          PUPPET
        end

        it { is_expected.to compile.with_all_deps }

        it do
          is_expected.to contain_archive('/tmp/adguardhome-sync.tar.gz').with(
            ensure: 'present',
            creates: '/tmp/adguardhome-sync',
            cleanup: true,
          )
        end

        it do
          is_expected.to contain_file('/usr/local/bin/adguardhome-sync').with(
            ensure: 'file',
            owner: 'root',
            group: 'root',
            mode: '0755',
          ).that_requires('Archive[/tmp/adguardhome-sync.tar.gz]')
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
