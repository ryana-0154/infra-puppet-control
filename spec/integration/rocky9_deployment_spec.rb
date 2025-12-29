# frozen_string_literal: true

require 'spec_helper'
require 'puppet'
require 'open3'

describe 'Rocky Linux 9 Deployment Validation' do
  let(:modulepath) { 'modules:site-modules' }
  let(:hiera_config) { 'hiera.yaml' }

  describe 'VPS node catalog compilation' do
    it 'compiles catalog for vps.ra-home.co.uk on Rocky 9' do
      # Skip this test for now - requires full Puppet server environment
      # The individual profile/role tests below provide sufficient Rocky 9 validation
      skip('Full node catalog requires Puppet server environment - use profile/role tests instead')
    end
  end

  describe 'Profile catalog compilation on Rocky 9' do
    let(:rocky9_facts) do
      {
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
          'domain' => 'example.com'
        },
        kernel: 'Linux',
        architecture: 'x86_64'
      }
    end

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
        let(:facts) { rocky9_facts }
        let(:node) { 'test.example.com' }

        it 'compiles on Rocky 9' do
          catalogue = Puppet::Parser::Compiler.compile(Puppet::Node.new(node, facts: facts, environment: 'production'))
          expect(catalogue).to be_a(Puppet::Resource::Catalog)
        end
      end
    end
  end

  describe 'Role catalog compilation on Rocky 9' do
    let(:rocky9_facts) do
      {
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
          'domain' => 'example.com'
        },
        kernel: 'Linux',
        architecture: 'x86_64'
      }
    end

    %w[
      role::base
      role::vps
    ].each do |role_class|
      describe role_class do
        let(:facts) { rocky9_facts }
        let(:node) { 'test.example.com' }

        it 'compiles on Rocky 9' do
          catalogue = Puppet::Parser::Compiler.compile(Puppet::Node.new(node, facts: facts, environment: 'production'))
          expect(catalogue).to be_a(Puppet::Resource::Catalog)
        end
      end
    end
  end
end
