require 'puppetlabs_spec_helper/rake_tasks'
require 'puppet-syntax/tasks/puppet-syntax'
require 'puppet-lint/tasks/puppet-lint'
require 'voxpupuli/acceptance/rake'


# Load beaker tasks if in acceptance test environment
begin
  require 'beaker-rspec/rake_task'
rescue LoadError
  # Beaker not available (likely not in acceptance test group)
end

PuppetLint.configuration.send('disable_140chars')
PuppetLint.configuration.send('disable_autoloader_layout')
PuppetLint.configuration.ignore_paths = ['spec/**/*.pp', 'pkg/**/*.pp', 'examples/**/*.pp']

desc 'Validate manifests, templates, and ruby files'
task :validate do
  Dir['manifests/**/*.pp'].each do |manifest|
    sh "puppet parser validate --noop #{manifest}"
  end
  Dir['spec/**/*.rb', 'lib/**/*.rb'].each do |ruby_file|
    sh "ruby -c #{ruby_file}" unless ruby_file =~ %r{spec/fixtures}
  end
  Dir['templates/**/*.epp'].each do |template|
    sh "puppet epp validate #{template}"
  end
end

# Acceptance test tasks
namespace :acceptance do
  desc 'Run acceptance tests on Debian 12'
  task :debian do
    sh 'BEAKER_set=debian12-docker bundle exec rspec spec/acceptance'
  end

  desc 'Run acceptance tests on Rocky 9'
  task :rocky do
    sh 'BEAKER_set=rocky9-docker bundle exec rspec spec/acceptance'
  end

  desc 'Run HA cluster acceptance tests'
  task :cluster do
    sh 'BEAKER_set=ha-cluster-docker bundle exec rspec spec/acceptance/02_ha_cluster_spec.rb'
  end

  desc 'Run all acceptance tests on all platforms'
  task :all do
    %w[debian rocky cluster].each do |platform|
      Rake::Task["acceptance:#{platform}"].invoke
    end
  end
end

desc 'Run acceptance tests (Debian 12 by default)'
task acceptance: 'acceptance:debian'
