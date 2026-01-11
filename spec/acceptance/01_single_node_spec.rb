# frozen_string_literal: true

require 'spec_helper_acceptance'

describe 'ha_adguard single node installation' do
  context 'with default parameters' do
    let(:pp) do
      <<-MANIFEST
        class { 'ha_adguard':
          ensure => present,
        }
      MANIFEST
    end

    it 'applies without errors' do
      apply_manifest_with_debug(pp, catch_failures: true)
    end

    it 'is idempotent' do
      apply_manifest_with_debug(pp, catch_changes: true)
    end

    describe 'system user and group' do
      it 'has adguard user' do
        on(default, 'id adguard')
      end

      it 'adguard user belongs to adguard group' do
        result = on(default, 'id -gn adguard')
        expect(result.stdout.strip).to eq('adguard')
      end

      it 'adguard user has correct home directory' do
        result = on(default, 'getent passwd adguard')
        expect(result.stdout).to match(%r{/var/lib/adguardhome})
      end

      it 'has adguard group' do
        on(default, 'getent group adguard')
      end
    end

    describe 'installation' do
      it 'has AdGuardHome binary' do
        on(default, 'test -f /opt/AdGuardHome/AdGuardHome')
      end

      it 'AdGuardHome binary is executable' do
        on(default, 'test -x /opt/AdGuardHome/AdGuardHome')
      end

      it 'AdGuardHome binary is owned by adguard' do
        result = on(default, 'stat -c "%U" /opt/AdGuardHome/AdGuardHome')
        expect(result.stdout.strip).to eq('adguard')
      end

      it 'has config directory' do
        on(default, 'test -d /etc/adguardhome')
      end

      it 'config directory is owned by adguard' do
        result = on(default, 'stat -c "%U" /etc/adguardhome')
        expect(result.stdout.strip).to eq('adguard')
      end

      it 'config directory has correct mode' do
        result = on(default, 'stat -c "%a" /etc/adguardhome')
        expect(result.stdout.strip).to eq('750')
      end

      it 'has data directory' do
        on(default, 'test -d /var/lib/adguardhome')
      end

      it 'data directory is owned by adguard' do
        result = on(default, 'stat -c "%U" /var/lib/adguardhome')
        expect(result.stdout.strip).to eq('adguard')
      end

      it 'data directory has correct mode' do
        result = on(default, 'stat -c "%a" /var/lib/adguardhome')
        expect(result.stdout.strip).to eq('750')
      end
    end

    describe 'configuration' do
      it 'has config file' do
        on(default, 'test -f /etc/adguardhome/AdGuardHome.yaml')
      end

      it 'config file is owned by adguard' do
        result = on(default, 'stat -c "%U" /etc/adguardhome/AdGuardHome.yaml')
        expect(result.stdout.strip).to eq('adguard')
      end

      it 'config file has correct mode' do
        result = on(default, 'stat -c "%a" /etc/adguardhome/AdGuardHome.yaml')
        expect(result.stdout.strip).to eq('600')
      end

      it 'config contains correct bind_host' do
        result = on(default, 'grep -E "bind_host:\\s+0\\.0\\.0\\.0" /etc/adguardhome/AdGuardHome.yaml')
        expect(result.exit_code).to eq(0)
      end

      it 'config contains correct bind_port' do
        result = on(default, 'grep -E "bind_port:\\s+3000" /etc/adguardhome/AdGuardHome.yaml')
        expect(result.exit_code).to eq(0)
      end

      it 'config contains correct DNS port' do
        result = on(default, 'grep -E "^\\s*port:\\s+53" /etc/adguardhome/AdGuardHome.yaml')
        expect(result.exit_code).to eq(0)
      end
    end

    describe 'systemd service' do
      it 'has systemd service file' do
        on(default, 'test -f /etc/systemd/system/adguardhome.service')
      end

      it 'service file contains correct ExecStart' do
        result = on(default, 'grep "ExecStart=/opt/AdGuardHome/AdGuardHome" /etc/systemd/system/adguardhome.service')
        expect(result.exit_code).to eq(0)
      end

      it 'service file contains correct User' do
        result = on(default, 'grep "User=adguard" /etc/systemd/system/adguardhome.service')
        expect(result.exit_code).to eq(0)
      end

      it 'service file contains correct Group' do
        result = on(default, 'grep "Group=adguard" /etc/systemd/system/adguardhome.service')
        expect(result.exit_code).to eq(0)
      end

      it 'service is enabled' do
        on(default, 'systemctl is-enabled adguardhome')
      end

      it 'service is running' do
        on(default, 'systemctl is-active adguardhome')
      end
    end

    describe 'functional tests' do
      it 'DNS service is listening on port 53' do
        wait_for_port(default, 53, 90)
      end

      it 'Web interface is listening on port 3000' do
        wait_for_port(default, 3000, 90)
      end

      it 'DNS queries work' do
        wait_for_service(default, 'adguardhome', 90)
        sleep 5 # Give DNS server time to fully initialize
        result = test_dns_query(default, '127.0.0.1', 'example.com')
        expect(result.exit_code).to eq(0)
      end

      it 'Web interface responds' do
        result = test_web_interface(default, 3000)
        expect(result.stdout.strip).to match(/^(200|302)$/)
      end
    end

    describe 'capabilities' do
      it 'AdGuard Home binary has CAP_NET_BIND_SERVICE' do
        result = on(default, 'getcap /opt/AdGuardHome/AdGuardHome')
        expect(result.stdout).to match(/cap_net_bind_service/)
      end

      it 'AdGuard Home binary has CAP_NET_RAW' do
        result = on(default, 'getcap /opt/AdGuardHome/AdGuardHome')
        expect(result.stdout).to match(/cap_net_raw/)
      end
    end
  end

  context 'with custom parameters' do
    let(:pp) do
      <<-MANIFEST
        class { 'ha_adguard':
          ensure       => present,
          bind_port    => 8080,
          dns_port     => 5353,
          user         => 'customuser',
          group        => 'customgroup',
          upstream_dns => ['1.1.1.1', '8.8.8.8'],
        }
      MANIFEST
    end

    it 'applies without errors' do
      apply_manifest_with_debug(pp, catch_failures: true)
    end

    describe 'custom user and group' do
      it 'has customuser' do
        on(default, 'id customuser')
      end

      it 'customuser belongs to customgroup' do
        result = on(default, 'id -gn customuser')
        expect(result.stdout.strip).to eq('customgroup')
      end

      it 'has customgroup' do
        on(default, 'getent group customgroup')
      end
    end

    describe 'custom ports' do
      it 'Web interface is listening on custom port 8080' do
        wait_for_port(default, 8080, 90)
      end

      it 'DNS service is listening on custom port 5353' do
        wait_for_port(default, 5353, 90)
      end
    end

    describe 'configuration reflects custom settings' do
      it 'config contains custom bind_port' do
        result = on(default, 'grep -E "bind_port:\\s+8080" /etc/adguardhome/AdGuardHome.yaml')
        expect(result.exit_code).to eq(0)
      end

      it 'config contains custom DNS port' do
        result = on(default, 'grep -E "^\\s*port:\\s+5353" /etc/adguardhome/AdGuardHome.yaml')
        expect(result.exit_code).to eq(0)
      end

      it 'config contains custom upstream DNS 1.1.1.1' do
        result = on(default, 'grep "1\\.1\\.1\\.1" /etc/adguardhome/AdGuardHome.yaml')
        expect(result.exit_code).to eq(0)
      end

      it 'config contains custom upstream DNS 8.8.8.8' do
        result = on(default, 'grep "8\\.8\\.8\\.8" /etc/adguardhome/AdGuardHome.yaml')
        expect(result.exit_code).to eq(0)
      end
    end
  end

  context 'with ensure => absent' do
    let(:pp) do
      <<-MANIFEST
        class { 'ha_adguard':
          ensure => absent,
        }
      MANIFEST
    end

    it 'removes the installation without errors' do
      apply_manifest_with_debug(pp, catch_failures: true)
    end

    describe 'service is stopped and disabled' do
      it 'adguardhome service is not running' do
        on(default, 'systemctl is-active adguardhome', acceptable_exit_codes: [3])
      end
    end

    describe 'files and directories are removed' do
      it 'AdGuardHome directory does not exist' do
        on(default, 'test ! -e /opt/AdGuardHome')
      end

      it 'config directory does not exist' do
        on(default, 'test ! -e /etc/adguardhome')
      end

      it 'data directory does not exist' do
        on(default, 'test ! -e /var/lib/adguardhome')
      end
    end

    describe 'user and group are removed' do
      it 'adguard user does not exist' do
        on(default, 'id adguard', acceptable_exit_codes: [1])
      end

      it 'adguard group does not exist' do
        on(default, 'getent group adguard', acceptable_exit_codes: [2])
      end
    end
  end
end
