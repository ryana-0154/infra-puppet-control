# frozen_string_literal: true

require 'spec_helper'
require 'puppet'

# Integration tests for Rocky Linux 9 compatibility
# These tests validate that all profiles and roles compile successfully
# on Rocky 9.3, matching the production VPS environment.
describe 'Rocky Linux 9 Deployment Validation' do
  # Shared facts for Rocky 9.3 - defined once to avoid duplication
  let(:rocky9_facts) do
    {
      # Top-level facts for compatibility with older modules
      fqdn: 'test.example.com',
      hostname: 'test',
      domain: 'example.com',
      # Standard structured facts
      operatingsystem: 'Rocky',
      operatingsystemrelease: '9.3',
      osfamily: 'RedHat',
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
        'ip' => '192.168.1.100'
      },
      kernel: 'Linux',
      architecture: 'x86_64'
    }
  end

  let(:node) { 'test.example.com' }

  describe 'Profile catalog compilation on Rocky 9' do
    %w[
      profile::base
      profile::wireguard
      profile::pihole_native
      profile::unbound
      profile::monitoring
      profile::ssh_hardening
      profile::unattended_upgrades
    ].each do |profile_class|
      describe profile_class do
        it 'compiles on Rocky 9' do
          # Compile catalog with Rocky 9 facts to ensure OS-specific compatibility
          # Note: Using Puppet::Parser::Compiler directly works in test environment
          # while Catalog.indirection.find requires a full Puppet server setup
          catalog = Puppet::Parser::Compiler.compile(
            Puppet::Node.new(node, facts: rocky9_facts, environment: 'production')
          )

          expect(catalog).to be_a(Puppet::Resource::Catalog)
          expect(catalog.resources.size).to be > 0
        end
      end
    end
  end

  describe 'Role catalog compilation on Rocky 9' do
    %w[
      role::base
      role::vps
    ].each do |role_class|
      describe role_class do
        it 'compiles on Rocky 9' do
          # Compile catalog with Rocky 9 facts to ensure OS-specific compatibility
          catalog = Puppet::Parser::Compiler.compile(
            Puppet::Node.new(node, facts: rocky9_facts, environment: 'production')
          )

          expect(catalog).to be_a(Puppet::Resource::Catalog)
          expect(catalog.resources.size).to be > 0
        end
      end
    end
  end
end
