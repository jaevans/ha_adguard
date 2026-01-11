# frozen_string_literal: true

require 'spec_helper'

describe 'ha_adguard' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      context 'with default parameters' do
        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_class('ha_adguard') }
        it { is_expected.to contain_class('ha_adguard::user') }
        it { is_expected.to contain_class('ha_adguard::install') }
        it { is_expected.to contain_class('ha_adguard::config') }
        it { is_expected.to contain_class('ha_adguard::service') }
        it { is_expected.not_to contain_class('ha_adguard::keepalived') }
        it { is_expected.not_to contain_class('ha_adguard::sync') }
        it { is_expected.not_to contain_class('ha_adguard::firewall') }
      end

      context 'with ensure => absent' do
        let(:params) { { ensure: 'absent' } }

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_class('ha_adguard::user') }
        it { is_expected.to contain_class('ha_adguard::install') }
        it { is_expected.to contain_class('ha_adguard::config') }
        it { is_expected.to contain_class('ha_adguard::service') }
      end

      context 'with keepalived enabled' do
        let(:params) do
          {
            keepalived_enabled: true,
            vip_address: '192.168.1.100',
          }
        end

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_class('ha_adguard::keepalived') }
      end

      context 'with keepalived enabled but no VIP' do
        let(:params) { { keepalived_enabled: true } }

        it { is_expected.to compile.and_raise_error(%r{vip_address is required}) }
      end

      context 'with sync enabled on replica' do
        let(:params) do
          {
            ha_enabled: true,
            ha_role: 'replica',
            sync_enabled: true,
            sync_origin_url: 'http://primary.example.com:3000',
            sync_password: sensitive('test123'),
          }
        end

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_class('ha_adguard::sync') }
      end

      context 'with sync enabled on replica but no origin URL' do
        let(:params) do
          {
            ha_enabled: true,
            ha_role: 'replica',
            sync_enabled: true,
          }
        end

        it { is_expected.to compile.and_raise_error(%r{sync_origin_url is required}) }
      end

      context 'with firewall management enabled' do
        let(:params) { { manage_firewall: true } }

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_class('ha_adguard::firewall') }
      end

      context 'with full HA configuration - primary' do
        let(:params) do
          {
            ha_enabled: true,
            ha_role: 'primary',
            cluster_nodes: ['dns1.example.com', 'dns2.example.com'],
            keepalived_enabled: true,
            vip_address: '192.168.1.100',
            vrrp_priority: 150,
            vrrp_router_id: 51,
            vrrp_auth_pass: 'supersecret',
            manage_firewall: true,
          }
        end

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_class('ha_adguard::keepalived') }
        it { is_expected.to contain_class('ha_adguard::firewall') }
        it { is_expected.not_to contain_class('ha_adguard::sync') }
      end

      context 'with full HA configuration - replica' do
        let(:params) do
          {
            ha_enabled: true,
            ha_role: 'replica',
            cluster_nodes: ['dns1.example.com', 'dns2.example.com'],
            keepalived_enabled: true,
            vip_address: '192.168.1.100',
            vrrp_priority: 100,
            sync_enabled: true,
            sync_origin_url: 'http://dns1.example.com:3000',
            sync_password: sensitive('supersecret'),
            manage_firewall: true,
          }
        end

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_class('ha_adguard::keepalived') }
        it { is_expected.to contain_class('ha_adguard::sync') }
        it { is_expected.to contain_class('ha_adguard::firewall') }
      end

      context 'with custom DNS configuration' do
        let(:params) do
          {
            bind_host: '127.0.0.1',
            bind_port: 8080,
            dns_port: 5353,
            upstream_dns: ['9.9.9.9', '1.1.1.1'],
            enable_dnssec: false,
            enable_filtering: false,
          }
        end

        it { is_expected.to compile.with_all_deps }
      end

      context 'with custom installation paths' do
        let(:params) do
          {
            install_dir: '/custom/adguard',
            config_dir: '/custom/config',
            work_dir: '/custom/work',
          }
        end

        it { is_expected.to compile.with_all_deps }
      end

      context 'with custom user and group' do
        let(:params) do
          {
            user: 'customuser',
            group: 'customgroup',
            uid: 5000,
            gid: 5000,
          }
        end

        it { is_expected.to compile.with_all_deps }
      end
    end
  end
end
