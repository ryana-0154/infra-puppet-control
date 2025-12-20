# frozen_string_literal: true

require 'puppetlabs_spec_helper/module_spec_helper'
require 'rspec-puppet-facts'

include RspecPuppetFacts

# Configure RSpec
RSpec.configure do |c|
  c.default_facts = {
    os: {
      'family'  => 'RedHat',
      'name'    => 'Rocky',
      'release' => {
        'major' => '8',
        'minor' => '9',
        'full'  => '8.9',
      },
    },
    networking: {
      'fqdn'     => 'test.example.com',
      'hostname' => 'test',
      'domain'   => 'example.com',
      'ip'       => '192.168.1.10',
    },
    kernel: 'Linux',
    kernelversion: '5.4.0',
    architecture: 'x86_64',
    operatingsystem: 'Rocky',
    operatingsystemrelease: '8.9',
    osfamily: 'RedHat',
  }
  c.hiera_config = File.expand_path(File.join(__FILE__, '..', 'fixtures', 'hiera.yaml'))
end

# Add site-modules to the module path
fixture_path = File.expand_path(File.join(__FILE__, '..', 'fixtures'))

RSpec.configure do |c|
  c.module_path = File.join(fixture_path, 'modules')
  c.manifest_dir = File.join(fixture_path, 'manifests')
end
