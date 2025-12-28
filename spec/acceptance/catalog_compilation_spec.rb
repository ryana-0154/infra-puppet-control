# frozen_string_literal: true

require 'spec_helper'
require 'puppet'

# Catalog compilation acceptance tests
# These tests actually compile catalogs with all dependencies to catch issues like:
# - Missing class definitions
# - Invalid class includes
# - Module dependency problems
# - Resource type mismatches
# rubocop:disable RSpec/BeforeAfterAll, RSpec/ContextWording
describe 'Catalog Compilation Acceptance Tests' do
  before(:all) do
    # Ensure modules are installed
    raise 'Run `bundle exec rake spec_prep` to install fixture modules first' unless File.directory?('spec/fixtures/modules')
  end

  # Test each profile can compile a catalog
  Dir.glob('site-modules/profile/manifests/**/*.pp').each do |manifest_file|
    # Skip init.pp placeholder files
    next if manifest_file.end_with?('/init.pp') && File.read(manifest_file).strip.empty?

    # Convert file path to class name
    # site-modules/profile/manifests/foo/bar.pp -> profile::foo::bar
    class_name = manifest_file
                 .sub('site-modules/', '')
                 .sub('/manifests/', '::')
                 .sub('.pp', '')
                 .gsub('/', '::')

    context "profile #{class_name}" do
      let(:node) { 'test.example.com' }
      let(:facts) do
        {
          fqdn: node,
          hostname: 'test',
          domain: 'example.com',
          os: {
            'family' => 'Debian',
            'name' => 'Ubuntu',
            'release' => {
              'major' => '22',
              'minor' => '04',
              'full' => '22.04'
            }
          },
          networking: {
            'fqdn' => node,
            'hostname' => 'test',
            'domain' => 'example.com',
            'ip' => '192.168.1.100'
          }
        }
      end

      it 'compiles a catalog without errors' do
        # This actually compiles a catalog with all dependencies
        # It will fail if:
        # - A class doesn't exist
        # - A resource type is invalid
        # - Dependencies are missing
        catalog = Puppet::Resource::Catalog.indirection.find(
          node,
          environment: Puppet::Node::Environment.create(:testing, ['site-modules', 'spec/fixtures/modules']),
          facts: Puppet::Node::Facts.new(node, facts),
          classes: [class_name]
        )

        expect(catalog).to be_a(Puppet::Resource::Catalog)
        expect(catalog.resources.size).to be > 0
      end
    end
  end

  # Test each role can compile a catalog
  Dir.glob('site-modules/role/manifests/**/*.pp').each do |manifest_file|
    next if manifest_file.end_with?('/init.pp') && File.read(manifest_file).strip.empty?

    class_name = manifest_file
                 .sub('site-modules/', '')
                 .sub('/manifests/', '::')
                 .sub('.pp', '')
                 .gsub('/', '::')

    context "role #{class_name}" do
      let(:node) { 'test.example.com' }
      let(:facts) do
        {
          fqdn: node,
          hostname: 'test',
          domain: 'example.com',
          os: {
            'family' => 'RedHat',
            'name' => 'Rocky',
            'release' => {
              'major' => '8',
              'minor' => '9',
              'full' => '8.9'
            }
          },
          networking: {
            'fqdn' => node,
            'hostname' => 'test',
            'domain' => 'example.com',
            'ip' => '192.168.1.100'
          }
        }
      end

      it 'compiles a catalog without errors' do
        catalog = Puppet::Resource::Catalog.indirection.find(
          node,
          environment: Puppet::Node::Environment.create(:testing, ['site-modules', 'spec/fixtures/modules']),
          facts: Puppet::Node::Facts.new(node, facts),
          classes: [class_name]
        )

        expect(catalog).to be_a(Puppet::Resource::Catalog)
        expect(catalog.resources.size).to be > 0
      end
    end
  end
end
# rubocop:enable RSpec/BeforeAfterAll, RSpec/ContextWording
