# frozen_string_literal: true

require 'puppetlabs_spec_helper/module_spec_helper'
require 'rspec-puppet-facts'

include RspecPuppetFacts # rubocop:disable Style/MixinUsage

# Configure RSpec
RSpec.configure do |c|
  c.default_facts = {
    os: {
      'family' => 'RedHat',
      'name' => 'Rocky',
      'release' => {
        'major' => '9',
        'minor' => '3',
        'full' => '9.3'
      }
    },
    networking: {
      'fqdn' => 'test.example.com',
      'hostname' => 'test',
      'domain' => 'example.com',
      'ip' => '192.168.1.10'
    },
    kernel: 'Linux',
    kernelversion: '5.14.0',
    architecture: 'x86_64',
    operatingsystem: 'Rocky',
    operatingsystemrelease: '9.3',
    osfamily: 'RedHat',
    path: '/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin'
  }
  c.hiera_config = File.expand_path(File.join(__FILE__, '..', 'fixtures', 'hiera.yaml'))

  # Explicitly add Rocky Linux to the supported OS list for testing
  # This ensures on_supported_os includes Rocky in addition to RedHat
  c.default_facter_version = '4.5.2'
end

# Add site-modules to the module path
fixture_path = File.expand_path(File.join(__FILE__, '..', 'fixtures'))

RSpec.configure do |c|
  c.module_path = File.join(fixture_path, 'modules')
end
