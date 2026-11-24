# frozen_string_literal: true

require 'spec_helper'

describe 'ha_adguard' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      # spec/hiera supplies sync_password as a plain string. The parameter is
      # Sensitive[String[1]], so this only compiles if the module's own
      # lookup_options (data/common.yaml) convert it.
      context 'with sync_password from Hiera as a plain string' do
        let(:hiera_config) { File.expand_path('../hiera/hiera.yaml', __dir__) }
        let(:params) do
          {
            ha_role: 'replica',
            sync_enabled: true,
            sync_origin_url: 'http://primary.example.com:3000',
          }
        end

        it { is_expected.to compile.with_all_deps }

        it 'renders the password into the sync config' do
          content = catalogue.resource('file', '/etc/adguardhome-sync/config.yaml')[:content]
          expect(content).to include('password: plain-from-hiera')
        end
      end

      context 'with keepalived enabled and no vrrp_interface set' do
        let(:params) { { keepalived_enabled: true, vip_address: '192.0.2.10' } }

        it { is_expected.to contain_keepalived__vrrp__instance('VI_ADGUARD').with_interface('eth0') }
      end
    end
  end
end
