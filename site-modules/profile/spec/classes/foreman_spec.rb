# frozen_string_literal: true

require 'spec_helper'

describe 'profile::foreman' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      context 'with default parameters' do
        it { is_expected.to compile.with_all_deps }
        it { is_expected.not_to contain_class('foreman') }
      end

      context 'with manage_foreman => true and required passwords' do
        let(:params) do
          {
            manage_foreman: true,
            admin_password: sensitive('securepassword123'),
            db_password: sensitive('dbpassword123')
          }
        end

        it { is_expected.to compile.with_all_deps }

        it {
          is_expected.to contain_class('foreman').with(
            db_type: 'postgresql',
            db_host: 'localhost',
            db_database: 'foreman',
            db_username: 'foreman'
          )
        }

        # NOTE: Service management is handled by the foreman class itself

        context 'with default passwords (should fail)' do
          let(:params) do
            {
              manage_foreman: true
            }
          end

          it { is_expected.to compile.and_raise_error(/admin_password must be set/) }
        end

        context 'with custom server_fqdn' do
          let(:params) do
            super().merge(
              server_fqdn: 'foreman.example.com'
            )
          end

          it {
            is_expected.to contain_class('foreman').with(
              servername: 'foreman.example.com'
            )
          }
        end

        context 'with Puppet Server enabled' do
          let(:params) do
            super().merge(
              enable_puppetserver: true,
              enable_enc: true,
              enable_reports: true
            )
          end

          it { is_expected.to compile.with_all_deps }
          it { is_expected.to contain_class('foreman::plugin::puppet') }
          # NOTE: ENC config handled by main foreman class, not separate puppetmaster class
        end

        context 'with Puppet Server disabled' do
          let(:params) do
            super().merge(
              enable_puppetserver: false
            )
          end

          it { is_expected.to compile.with_all_deps }
          it { is_expected.not_to contain_class('foreman::plugin::puppet') }
          # NOTE: No foreman::puppetmaster class exists in theforeman-foreman module
        end

        context 'with custom organization and location' do
          let(:params) do
            super().merge(
              initial_organization: { 'name' => 'My Org', 'description' => 'Test Org' },
              initial_location: { 'name' => 'Data Center', 'description' => 'Test DC' }
            )
          end

          it { is_expected.to compile.with_all_deps }

          it {
            is_expected.to contain_class('foreman').with(
              initial_organization: 'My Org',
              initial_location: 'Data Center'
            )
          }
        end
      end
    end
  end
end
