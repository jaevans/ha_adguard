# frozen_string_literal: true

require 'puppetlabs_spec_helper/module_spec_helper'
require 'rspec-puppet-facts'

include RspecPuppetFacts

RSpec.configure do |c|
  c.default_facts = {
    os: {
      family: 'Debian',
      name: 'Debian',
      release: {
        major: '12',
        full: '12.0',
      },
      architecture: 'x86_64',
    },
    kernel: 'Linux',
    networking: {
      fqdn: 'test.example.com',
      hostname: 'test',
      domain: 'example.com',
    },
  }

  c.before :each do
    # Set default Puppet settings for all tests
    Puppet[:strict_variables] = true
  end
end

# Coverage report
at_exit { RSpec::Puppet::Coverage.report! }
