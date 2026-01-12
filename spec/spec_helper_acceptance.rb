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

# Ruby 3.2+ compatibility fixes for deprecated methods
unless Dir.respond_to?(:exists?)
  class Dir
    class << self
      alias exists? exist?
    end
  end
end

unless File.respond_to?(:exists?)
  class File
    class << self
      alias exists? exist?
    end
  end
end

# require 'beaker-rspec'
require 'voxpupuli/acceptance/spec_helper_acceptance'

configure_beaker(modules: :fixtures)

RSpec.configure do |c|
  # Readable test descriptions
  c.formatter = :documentation

  # # Configure all nodes in nodeset
  # c.before :suite do
  #   hosts.each do |host|
  #     # Install module dependencies from .fixtures.yml
  #     on(host, puppet('module', 'install', 'puppetlabs-stdlib'))
  #     on(host, puppet('module', 'install', 'puppet-archive'))
  #     on(host, puppet('module', 'install', 'puppetlabs-firewall'))
  #     on(host, puppet('module', 'install', 'puppet-systemd'))
  #     on(host, puppet('module', 'install', 'puppet-keepalived'))
  #     on(host, puppet('module', 'install', 'puppetlabs-concat'))

  #     # Ensure /etc/puppet exists for hiera
  #     on(host, 'mkdir -p /etc/puppetlabs/puppet')
  #     on(host, 'mkdir -p /etc/puppetlabs/code/environments/production/data')
  #   end
  # end
end

# Helper method to get the default (first) host
def default
  hosts.first
end

# Helper to apply manifest and check for errors
def apply_manifest_with_debug(manifest, opts = {})
  # Set defaults, but don't override if catch_changes or expect_* is specified
  default_opts = {
    debug: true,
    trace: true,
  }

  # Only add catch_failures if no other catch/expect option is specified
  default_opts[:catch_failures] = true unless opts.key?(:catch_changes) || opts.key?(:expect_changes) || opts.key?(:expect_failures)

  opts = default_opts.merge(opts)

  # Apply to the default host (first host in nodeset)
  host = hosts.first
  apply_manifest_on(host, manifest, opts)
end

# Helper to get host IP address
def get_host_ip(host)
  on(host, "hostname -I | awk '{print $1}'").stdout.strip
end

# Helper to wait for service to be running
def wait_for_service(host, service_name, timeout = 10)
  max_attempts = 10
  sleep_time = [timeout / max_attempts.to_f, 1].max

  max_attempts.times do |attempt|
    result = on(host, "systemctl is-active #{service_name}", acceptable_exit_codes: [0, 3])
    break if result.stdout.strip == 'active'

    raise "Service #{service_name} did not start within #{timeout} seconds" if attempt == max_attempts - 1

    sleep sleep_time
  end
end

# Helper to wait for port to be listening
def wait_for_port(host, port, timeout = 10)
  max_attempts = 10
  sleep_time = [timeout / max_attempts.to_f, 1].max

  max_attempts.times do |attempt|
    result = on(host, "ss -tuln | grep -E ':#{port}\\s' || netstat -tuln | grep -E ':#{port}\\s'", acceptable_exit_codes: [0, 1])
    break if result.exit_code.zero?

    raise "Port #{port} did not open within #{timeout} seconds" if attempt == max_attempts - 1

    sleep sleep_time
  end
end

# Helper to test DNS query
def test_dns_query(host, dns_server = '127.0.0.1', query = 'example.com')
  on(host, "dig @#{dns_server} #{query} +short +time=5", acceptable_exit_codes: [0])
end

# Helper to test web interface
def test_web_interface(host, port = 3000)
  on(host, "curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:#{port}/", acceptable_exit_codes: [0])
end
