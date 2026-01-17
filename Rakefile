require 'voxpupuli/test/rake'
require 'puppet-syntax/tasks/puppet-syntax'
require 'puppet-lint/tasks/puppet-lint'
require 'voxpupuli/acceptance/rake'

PuppetLint.configuration.send('disable_140chars')
PuppetLint.configuration.send('disable_autoloader_layout')
PuppetLint.configuration.ignore_paths = ['spec/**/*.pp', 'pkg/**/*.pp', 'examples/**/*.pp', 'vendor/**/*.pp']

desc 'Validate manifests, templates, and ruby files'
task :validate do
  Dir['manifests/**/*.pp'].each do |manifest|
    sh "puppet parser validate --noop #{manifest}"
  end
  Dir['spec/**/*.rb', 'lib/**/*.rb'].each do |ruby_file|
    sh "ruby -c #{ruby_file}" unless ruby_file =~ %r{spec/fixtures|vendor}
  end
  Dir['templates/**/*.epp'].each do |template|
    sh "puppet epp validate #{template}"
  end
end

# Configure acceptance tests with voxpupuli-acceptance
# This provides the default 'beaker' task and platform-specific tasks
namespace :acceptance do
  {
    debian: 'debian12-docker',
    rocky: 'rocky9-docker',
    cluster: 'ha-cluster-docker'
  }.each do |name, nodeset|
    desc "Run acceptance tests on #{nodeset}"
    RSpec::Core::RakeTask.new(name => 'fixtures:prep') do |t|
      t.pattern = if name == :cluster
                    'spec/acceptance/02_ha_cluster_spec.rb'
                  else
                    'spec/acceptance'
                  end
      ENV['BEAKER_set'] = nodeset
      # Set DOCKER_IN_DOCKER only if we're already in a container (dev container, CI, etc.)
      # and the variable isn't already set
      if ENV['DOCKER_IN_DOCKER'].nil? && (File.exist?('/.dockerenv') || File.exist?('/run/.containerenv'))
        ENV['DOCKER_IN_DOCKER'] = '1'
      end
    end
  end

  desc 'Run all acceptance tests on all platforms'
  task all: %i[debian rocky cluster]
end

desc 'Run acceptance tests (Debian 12 by default)'
task acceptance: 'acceptance:debian'
