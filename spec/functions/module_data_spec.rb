# frozen_string_literal: true

require 'spec_helper'

# Puppet only reads a module's Hiera data when hiera.yaml sits at the module
# root. This module's lives at data/hiera.yaml, so nothing under data/ is ever
# consulted.
describe 'lookup' do
  let(:common_entry) do
    YAML.safe_load_file(File.expand_path('../../data/common.yaml', __dir__)).find { |k, _| k.start_with?('ha_adguard::') }
  end

  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      it "returns a key from the module's data/common.yaml" do
        key, value = common_entry
        is_expected.to run.with_params(key).and_return(value)
      end
    end
  end
end
