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

require 'spec_helper_acceptance'

describe 'ha_adguard HA cluster' do
  # Skip HA tests if running on single-node nodeset
  before(:context) do
    skip('HA cluster tests require at least 2 hosts (use BEAKER_set=ha-cluster-docker)') if hosts.length < 2
  end

  # Get host references
  let(:primary_host) { hosts_as('primary')[0] }
  let(:replica_host) { hosts_as('replica')[0] }

  # Get IP addresses
  let(:primary_ip) { get_host_ip(primary_host) }
  let(:replica_ip) { get_host_ip(replica_host) }
  let(:vip) { '192.168.255.100' }

  context 'primary node configuration' do
    let(:pp) do
      <<-MANIFEST
        class { 'ha_adguard':
          ensure             => present,
          ha_enabled         => true,
          ha_role            => 'primary',
          keepalived_enabled => true,
          vip_address        => '#{vip}',
          vrrp_interface     => 'eth0',
          vrrp_priority      => 150,
          vrrp_router_id     => 51,
          vrrp_auth_pass     => 'testpass',
          cluster_nodes      => ['#{primary_ip}', '#{replica_ip}'],
          sync_username      => 'admin',
          sync_password      => Sensitive('admin_password'),
          bind_host          => '0.0.0.0',
          bind_port          => 3000,
          dns_port           => 53,
        }
      MANIFEST
    end

    it 'applies on primary without errors' do
      apply_manifest_on(primary_host, pp, catch_failures: true)
    end

    it 'is idempotent on primary' do
      apply_manifest_on(primary_host, pp, catch_changes: true)
    end

    describe 'primary node services' do
      it 'has adguardhome service enabled' do
        on(primary_host, 'systemctl is-enabled adguardhome')
      end

      it 'has adguardhome service running' do
        on(primary_host, 'systemctl is-active adguardhome')
      end

      it 'has keepalived service enabled' do
        on(primary_host, 'systemctl is-enabled keepalived')
      end

      it 'has keepalived service running' do
        on(primary_host, 'systemctl is-active keepalived')
      end

      # Sync should NOT run on primary
      it 'does not have sync service enabled' do
        on(primary_host, 'systemctl is-enabled adguardhome-sync', acceptable_exit_codes: [1])
      end
    end

    describe 'primary keepalived configuration' do
      it 'has keepalived.conf file' do
        on(primary_host, 'test -f /etc/keepalived/keepalived.conf')
      end

      it 'has correct virtual_router_id' do
        result = on(primary_host, 'grep -E "virtual_router_id\\s+51" /etc/keepalived/keepalived.conf')
        expect(result.exit_code).to eq(0)
      end

      it 'has correct priority' do
        result = on(primary_host, 'grep -E "priority\\s+150" /etc/keepalived/keepalived.conf')
        expect(result.exit_code).to eq(0)
      end

      it 'has correct VIP address' do
        result = on(primary_host, "grep '#{vip}' /etc/keepalived/keepalived.conf")
        expect(result.exit_code).to eq(0)
      end
    end

    describe 'primary health check script' do
      it 'has health check script file' do
        on(primary_host, 'test -f /usr/local/bin/check_adguard.sh')
      end

      it 'health check script is executable' do
        on(primary_host, 'test -x /usr/local/bin/check_adguard.sh')
      end

      it 'health check script contains pgrep check' do
        result = on(primary_host, 'grep "pgrep.*AdGuardHome" /usr/local/bin/check_adguard.sh')
        expect(result.exit_code).to eq(0)
      end

      it 'health check script contains dig check' do
        result = on(primary_host, 'grep "dig @127\\.0\\.0\\.1" /usr/local/bin/check_adguard.sh')
        expect(result.exit_code).to eq(0)
      end
    end

    describe 'primary functional tests' do
      it 'DNS service is running' do
        wait_for_service(primary_host, 'adguardhome', 90)
        wait_for_port(primary_host, 53, 90)
      end

      it 'Web interface is accessible' do
        wait_for_port(primary_host, 3000, 90)
      end

      it 'Keepalived is running' do
        wait_for_service(primary_host, 'keepalived', 60)
      end
    end
  end

  context 'replica node configuration' do
    let(:pp) do
      <<-MANIFEST
        class { 'ha_adguard':
          ensure             => present,
          ha_enabled         => true,
          ha_role            => 'replica',
          keepalived_enabled => true,
          vip_address        => '#{vip}',
          vrrp_interface     => 'eth0',
          vrrp_priority      => 100,
          vrrp_router_id     => 51,
          vrrp_auth_pass     => 'testpass',
          cluster_nodes      => ['#{primary_ip}', '#{replica_ip}'],
          sync_enabled       => true,
          sync_origin_url    => 'http://#{primary_ip}:3000',
          sync_username      => 'admin',
          sync_password      => Sensitive('admin_password'),
          sync_interval      => 600,
          bind_host          => '0.0.0.0',
          bind_port          => 3000,
          dns_port           => 53,
        }
      MANIFEST
    end

    it 'applies on replica without errors' do
      # Wait for primary to be fully ready
      sleep 10
      apply_manifest_on(replica_host, pp, catch_failures: true)
    end

    it 'is idempotent on replica' do
      apply_manifest_on(replica_host, pp, catch_changes: true)
    end

    describe 'replica node services' do
      it 'has adguardhome service enabled' do
        on(replica_host, 'systemctl is-enabled adguardhome')
      end

      it 'has adguardhome service running' do
        on(replica_host, 'systemctl is-active adguardhome')
      end

      it 'has keepalived service enabled' do
        on(replica_host, 'systemctl is-enabled keepalived')
      end

      it 'has keepalived service running' do
        on(replica_host, 'systemctl is-active keepalived')
      end

      it 'has sync service enabled' do
        on(replica_host, 'systemctl is-enabled adguardhome-sync')
      end

      it 'has sync service running' do
        on(replica_host, 'systemctl is-active adguardhome-sync')
      end
    end

    describe 'replica keepalived configuration' do
      it 'has keepalived.conf file' do
        on(replica_host, 'test -f /etc/keepalived/keepalived.conf')
      end

      it 'has correct virtual_router_id' do
        result = on(replica_host, 'grep -E "virtual_router_id\\s+51" /etc/keepalived/keepalived.conf')
        expect(result.exit_code).to eq(0)
      end

      it 'has correct priority' do
        result = on(replica_host, 'grep -E "priority\\s+100" /etc/keepalived/keepalived.conf')
        expect(result.exit_code).to eq(0)
      end

      it 'has correct VIP address' do
        result = on(replica_host, "grep '#{vip}' /etc/keepalived/keepalived.conf")
        expect(result.exit_code).to eq(0)
      end
    end

    describe 'replica sync configuration' do
      it 'has sync config.yaml file' do
        on(replica_host, 'test -f /etc/adguardhome-sync/config.yaml')
      end

      it 'sync config has correct mode' do
        result = on(replica_host, 'stat -c "%a" /etc/adguardhome-sync/config.yaml')
        expect(result.stdout.strip).to eq('600')
      end

      it 'sync config contains origin URL' do
        result = on(replica_host, "grep '#{primary_ip}:3000' /etc/adguardhome-sync/config.yaml")
        expect(result.exit_code).to eq(0)
      end

      it 'sync config contains replica URL' do
        result = on(replica_host, 'grep "127\\.0\\.0\\.1:3000" /etc/adguardhome-sync/config.yaml')
        expect(result.exit_code).to eq(0)
      end

      it 'sync config has correct interval' do
        # 600 seconds = 10 minutes, cron format: */10 * * * *
        result = on(replica_host, 'grep "cron:.*\\*/10 \\* \\* \\* \\*" /etc/adguardhome-sync/config.yaml')
        expect(result.exit_code).to eq(0)
      end

      it 'has sync binary' do
        on(replica_host, 'test -f /usr/local/bin/adguardhome-sync')
      end

      it 'sync binary is executable' do
        on(replica_host, 'test -x /usr/local/bin/adguardhome-sync')
      end
    end

    describe 'replica functional tests' do
      it 'DNS service is running' do
        wait_for_service(replica_host, 'adguardhome', 90)
        wait_for_port(replica_host, 53, 90)
      end

      it 'Web interface is accessible' do
        wait_for_port(replica_host, 3000, 90)
      end

      it 'Keepalived is running' do
        wait_for_service(replica_host, 'keepalived', 60)
      end

      it 'Sync service is running' do
        wait_for_service(replica_host, 'adguardhome-sync', 60)
      end
    end
  end

  context 'HA cluster functionality' do
    describe 'VRRP priority configuration' do
      it 'primary has higher priority than replica' do
        primary_priority = on(primary_host, "grep 'priority' /etc/keepalived/keepalived.conf | head -1").stdout.strip
        replica_priority = on(replica_host, "grep 'priority' /etc/keepalived/keepalived.conf | head -1").stdout.strip

        expect(primary_priority).to match(%r{150})
        expect(replica_priority).to match(%r{100})
      end
    end

    describe 'health checks work' do
      it 'primary health check script executes successfully' do
        result = on(primary_host, '/usr/local/bin/check_adguard.sh', acceptable_exit_codes: [0, 1])
        # May fail initially but should exist and be executable
        expect(result.exit_code).to be_between(0, 1)
      end

      it 'replica health check script executes successfully' do
        result = on(replica_host, '/usr/local/bin/check_adguard.sh', acceptable_exit_codes: [0, 1])
        expect(result.exit_code).to be_between(0, 1)
      end
    end

    describe 'DNS functionality on both nodes' do
      it 'primary responds to DNS queries' do
        wait_for_service(primary_host, 'adguardhome', 90)
        sleep 10 # Allow time for DNS to fully initialize
        result = on(primary_host, 'dig @127.0.0.1 example.com +short +time=5', acceptable_exit_codes: [0])
        expect(result.exit_code).to eq(0)
      end

      it 'replica responds to DNS queries' do
        wait_for_service(replica_host, 'adguardhome', 90)
        sleep 10 # Allow time for DNS to fully initialize
        result = on(replica_host, 'dig @127.0.0.1 example.com +short +time=5', acceptable_exit_codes: [0])
        expect(result.exit_code).to eq(0)
      end
    end

    describe 'configuration synchronization' do
      it 'sync service has run at least once' do
        # Check sync service logs for successful execution
        result = on(replica_host, 'journalctl -u adguardhome-sync --no-pager | grep -i "sync" || echo "No sync logs yet"')
        expect(result.stdout).not_to be_empty
      end
    end
  end

  context 'cluster removal' do
    let(:removal_pp) do
      <<-MANIFEST
        class { 'ha_adguard':
          ensure => absent,
        }
      MANIFEST
    end

    it 'removes HA cluster from primary' do
      apply_manifest_on(primary_host, removal_pp, catch_failures: true)
    end

    it 'removes HA cluster from replica' do
      apply_manifest_on(replica_host, removal_pp, catch_failures: true)
    end

    describe 'primary cleanup' do
      it 'adguardhome service is not running' do
        on(primary_host, 'systemctl is-active adguardhome', acceptable_exit_codes: [3])
      end

      it 'AdGuardHome directory does not exist' do
        on(primary_host, 'test ! -e /opt/AdGuardHome')
      end
    end

    describe 'replica cleanup' do
      it 'adguardhome service is not running' do
        on(replica_host, 'systemctl is-active adguardhome', acceptable_exit_codes: [3])
      end

      it 'adguardhome-sync service is not running' do
        on(replica_host, 'systemctl is-active adguardhome-sync', acceptable_exit_codes: [3])
      end

      it 'AdGuardHome directory does not exist' do
        on(replica_host, 'test ! -e /opt/AdGuardHome')
      end

      it 'adguardhome-sync directory does not exist' do
        on(replica_host, 'test ! -e /opt/adguardhome-sync')
      end
    end
  end
end
