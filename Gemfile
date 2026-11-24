source 'https://rubygems.org'

gem 'bigdecimal', '4.1.3'
# jgrep (via facterdb) calls JSON.create_id=, which json 3 removed.
gem 'json', '2.21.2'
gem 'metadata-json-lint', '5.1.0'
gem 'openfact', '6.2.1'
gem 'openvox', ENV.fetch('PUPPET_GEM_VERSION', '8.31.0')
gem 'parallel_tests', '5.8.0'
gem 'rake', '13.4.2'
gem 'rspec-puppet', '6.0.0'
gem 'rspec-puppet-facts', '6.3.1'
gem 'syslog', '0.4.0'
gem 'voxpupuli-test', '15.0.0'

group :acceptance do
  gem 'beaker', '7.8.3'
  gem 'beaker-docker', '3.1.3'
  gem 'beaker-rspec', '9.1.0'
  gem 'serverspec', '2.43.0'
  gem 'voxpupuli-acceptance', '4.4.0'
  gem 'beaker_puppet_helpers', '3.3.1', require: false
end
