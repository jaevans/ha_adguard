# frozen_string_literal: true

require 'spec_helper'

describe 'ha_adguard::keepalived' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      context 'with keepalived disabled' do
        let(:pre_condition) { 'include ha_adguard' }

        it { is_expected.to compile.with_all_deps }
        it { is_expected.not_to contain_class('keepalived') }
        it { is_expected.not_to contain_keepalived__vrrp__instance('VI_ADGUARD') }
        it { is_expected.not_to contain_keepalived__vrrp__script('check_adguard') }
      end

      context 'with keepalived enabled' do
        let(:pre_condition) do
          <<-PUPPET
          class { 'ha_adguard':
            keepalived_enabled => true,
            vip_address        => '192.168.1.100',
            vrrp_priority      => 150,
            vrrp_router_id     => 51,
            vrrp_auth_pass     => 'supersecret',
            vrrp_interface     => 'eth0',
          }
          PUPPET
        end

        it { is_expected.to compile.with_all_deps }

        it do
          is_expected.to contain_class('keepalived').with(
            service_manage: true,
          )
        end

        it do
          is_expected.to contain_file('/usr/local/bin/check_adguard.sh').with(
            ensure: 'file',
            owner: 'root',
            group: 'root',
            mode: '0755',
          )
        end

        it 'generates valid health check script' do
          content = catalogue.resource('file', '/usr/local/bin/check_adguard.sh')[:content]
          expect(content).to match(%r{#!/bin/bash})
          expect(content).to match(%r{AdGuardHome})
          expect(content).to match(/DNS_PORT=53/)
          expect(content).to match(%r{pgrep})
          expect(content).to match(%r{dig|nslookup})
        end

        it do
          is_expected.to contain_keepalived__vrrp__script('check_adguard').with(
            script: '/usr/local/bin/check_adguard.sh',
            interval: 2,
            weight: -20,
          ).that_requires('File[/usr/local/bin/check_adguard.sh]')
        end

        it do
          is_expected.to contain_keepalived__vrrp__instance('VI_ADGUARD').with(
            interface: 'eth0',
            state: 'BACKUP',
            virtual_router_id: 51,
            priority: 150,
            auth_type: 'PASS',
            auth_pass: 'supersecret',
            virtual_ipaddress: ['192.168.1.100'],
            track_script: ['check_adguard'],
          )
        end
      end

      context 'with custom health check interval' do
        let(:pre_condition) do
          <<-PUPPET
          class { 'ha_adguard':
            keepalived_enabled     => true,
            vip_address            => '192.168.1.100',
            health_check_interval  => 5,
          }
          PUPPET
        end

        it do
          is_expected.to contain_keepalived__vrrp__script('check_adguard').with(
            interval: 5,
          )
        end
      end

      context 'with custom DNS port' do
        let(:pre_condition) do
          <<-PUPPET
          class { 'ha_adguard':
            keepalived_enabled => true,
            vip_address        => '192.168.1.100',
            dns_port           => 5353,
          }
          PUPPET
        end

        it 'uses custom DNS port in health check script' do
          content = catalogue.resource('file', '/usr/local/bin/check_adguard.sh')[:content]
          expect(content).to match(/DNS_PORT=5353/)
        end
      end

      context 'with ensure => absent and keepalived enabled' do
        let(:pre_condition) do
          <<-PUPPET
          class { 'ha_adguard':
            ensure             => 'absent',
            keepalived_enabled => true,
            vip_address        => '192.168.1.100',
          }
          PUPPET
        end

        it { is_expected.to compile.with_all_deps }

        # Note: keepalived::vrrp::instance and keepalived::vrrp::script resources
        # do not support ensure => absent, so they won't be declared during removal.
        # Only the health check script file is removed.
        it { is_expected.not_to contain_keepalived__vrrp__instance('VI_ADGUARD') }
        it { is_expected.not_to contain_keepalived__vrrp__script('check_adguard') }

        it do
          is_expected.to contain_file('/usr/local/bin/check_adguard.sh').with(
            ensure: 'absent',
          )
        end
      end

      context 'replica node configuration' do
        let(:pre_condition) do
          <<-PUPPET
          class { 'ha_adguard':
            ha_role            => 'replica',
            keepalived_enabled => true,
            vip_address        => '192.168.1.100',
            vrrp_priority      => 100,
          }
          PUPPET
        end

        it do
          is_expected.to contain_keepalived__vrrp__instance('VI_ADGUARD').with(
            priority: 100,
            state: 'BACKUP',
          )
        end
      end
    end
  end
end
