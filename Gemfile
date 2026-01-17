source 'https://rubygems.org'

gem 'bigdecimal'
gem 'metadata-json-lint', '~> 5.0'
gem 'openfact', '~> 5.3.0'
gem 'openvox', ENV['PUPPET_GEM_VERSION'] || '~> 8.0'
gem 'parallel_tests', '~> 5.5'
# gem 'puppetlabs_spec_helper', '~> 7.0'
gem 'rspec-puppet', '~> 5.0'
gem 'rspec-puppet-facts', '~> 6.0'
gem 'syslog'
# gem 'voxpupuli-rubocop', '~> 5.1'
gem 'voxpupuli-test', '~> 13.2'

group :acceptance do
  gem 'beaker', '~> 7.0'
  gem 'beaker-docker'
  gem 'beaker-rspec'
  gem 'serverspec', '~> 2.43'
  gem 'voxpupuli-acceptance', '~> 4.3'
  gem "beaker_puppet_helpers",                                                     require: false

end
