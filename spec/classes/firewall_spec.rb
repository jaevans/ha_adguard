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

describe 'ha_adguard::firewall' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      context 'with manage_firewall => false' do
        let(:pre_condition) { 'include ha_adguard' }

        it { is_expected.to compile.with_all_deps }
        it { is_expected.not_to contain_firewall('100 allow DNS tcp') }
        it { is_expected.not_to contain_firewall('100 allow DNS udp') }
        it { is_expected.not_to contain_firewall('100 allow AdGuard web UI') }
      end

      context 'with manage_firewall => true' do
        let(:pre_condition) do
          <<-PUPPET
          class { 'ha_adguard':
            manage_firewall => true,
          }
          PUPPET
        end

        it { is_expected.to compile.with_all_deps }

        it do
          is_expected.to contain_firewall('100 allow DNS tcp').with(
            dport: 53,
            proto: 'tcp',
            jump: 'accept'
          )
        end

        it do
          is_expected.to contain_firewall('100 allow DNS udp').with(
            dport: 53,
            proto: 'udp',
            jump: 'accept'
          )
        end

        it do
          is_expected.to contain_firewall('100 allow AdGuard web UI').with(
            dport: 3000,
            proto: 'tcp',
            jump: 'accept'
          )
        end

        it { is_expected.not_to contain_firewall('100 allow VRRP') }
        it { is_expected.not_to contain_firewall('100 allow adguardhome-sync API') }
      end

      context 'with manage_firewall and keepalived enabled' do
        let(:pre_condition) do
          <<-PUPPET
          class { 'ha_adguard':
            manage_firewall    => true,
            keepalived_enabled => true,
            vip_address        => '192.168.1.100',
          }
          PUPPET
        end

        it { is_expected.to compile.with_all_deps }

        it do
          is_expected.to contain_firewall('100 allow VRRP').with(
            proto: 'vrrp',
            jump: 'accept'
          )
        end
      end

      context 'with manage_firewall and sync enabled' do
        let(:pre_condition) do
          <<-PUPPET
          class { 'ha_adguard':
            manage_firewall    => true,
            ha_role            => 'replica',
            sync_enabled       => true,
            sync_origin_url    => 'http://primary.example.com:3000',
            sync_api_enabled   => true,
          }
          PUPPET
        end

        it { is_expected.to compile.with_all_deps }

        it do
          is_expected.to contain_firewall('100 allow adguardhome-sync API').with(
            dport: 8080,
            proto: 'tcp',
            jump: 'accept'
          )
        end
      end

      context 'with sync API disabled' do
        let(:pre_condition) do
          <<-PUPPET
          class { 'ha_adguard':
            manage_firewall    => true,
            ha_role            => 'replica',
            sync_enabled       => true,
            sync_origin_url    => 'http://primary.example.com:3000',
            sync_api_enabled   => false,
          }
          PUPPET
        end

        it { is_expected.to compile.with_all_deps }
        it { is_expected.not_to contain_firewall('100 allow adguardhome-sync API') }
      end

      context 'with custom ports' do
        let(:pre_condition) do
          <<-PUPPET
          class { 'ha_adguard':
            manage_firewall => true,
            dns_port        => 5353,
            bind_port       => 8080,
            sync_enabled    => true,
            ha_role         => 'replica',
            sync_origin_url => 'http://primary.example.com:3000',
            sync_api_port   => 9090,
          }
          PUPPET
        end

        it do
          is_expected.to contain_firewall('100 allow DNS tcp').with(
            dport: 5353
          )
        end

        it do
          is_expected.to contain_firewall('100 allow DNS udp').with(
            dport: 5353
          )
        end

        it do
          is_expected.to contain_firewall('100 allow AdGuard web UI').with(
            dport: 8080
          )
        end

        it do
          is_expected.to contain_firewall('100 allow adguardhome-sync API').with(
            dport: 9090
          )
        end
      end

      context 'with ensure => absent and manage_firewall => true' do
        let(:pre_condition) do
          <<-PUPPET
          class { 'ha_adguard':
            ensure             => 'absent',
            manage_firewall    => true,
            keepalived_enabled => true,
            vip_address        => '192.168.1.100',
            sync_enabled       => true,
            ha_role            => 'replica',
            sync_origin_url    => 'http://primary.example.com:3000',
          }
          PUPPET
        end

        it { is_expected.to compile.with_all_deps }

        it do
          is_expected.to contain_firewall('100 allow DNS tcp').with(
            ensure: 'absent'
          )
        end

        it do
          is_expected.to contain_firewall('100 allow DNS udp').with(
            ensure: 'absent'
          )
        end

        it do
          is_expected.to contain_firewall('100 allow AdGuard web UI').with(
            ensure: 'absent'
          )
        end

        it do
          is_expected.to contain_firewall('100 allow VRRP').with(
            ensure: 'absent'
          )
        end

        it do
          is_expected.to contain_firewall('100 allow adguardhome-sync API').with(
            ensure: 'absent'
          )
        end
      end

      context 'full HA configuration with all firewall rules' do
        let(:pre_condition) do
          <<-PUPPET
          class { 'ha_adguard':
            manage_firewall    => true,
            ha_enabled         => true,
            ha_role            => 'replica',
            keepalived_enabled => true,
            vip_address        => '192.168.1.100',
            sync_enabled       => true,
            sync_origin_url    => 'http://primary.example.com:3000',
            sync_api_enabled   => true,
          }
          PUPPET
        end

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_firewall('100 allow DNS tcp') }
        it { is_expected.to contain_firewall('100 allow DNS udp') }
        it { is_expected.to contain_firewall('100 allow AdGuard web UI') }
        it { is_expected.to contain_firewall('100 allow VRRP') }
        it { is_expected.to contain_firewall('100 allow adguardhome-sync API') }
      end
    end
  end
end
