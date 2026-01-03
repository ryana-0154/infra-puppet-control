# frozen_string_literal: true

require 'spec_helper'

describe 'profile::puppetdb' do
  on_supported_os.each do |os, os_facts|
    context "when on #{os}" do
      let(:facts) { os_facts }

      context 'with default parameters (manage_puppetdb => false)' do
        it { is_expected.to compile.with_all_deps }
        it { is_expected.not_to contain_class('puppetdb') }
        it { is_expected.not_to contain_class('puppetdb::master::config') }
      end

      context 'with manage_puppetdb => true' do
        let(:params) do
          {
            manage_puppetdb: true,
            postgres_password: sensitive('test_password')
          }
        end

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_class('puppetdb') }
        it { is_expected.to contain_class('puppetdb::master::config') }

        it do
          is_expected.to contain_class('puppetdb').with(
            database_host: 'localhost',
            database_port: 5432,
            database_name: 'puppetdb',
            database_username: 'puppetdb',
            database_password: 'test_password',
            manage_dbserver: false
          )
        end

        it do
          is_expected.to contain_class('puppetdb::master::config').with(
            puppetdb_server: os_facts[:networking][:fqdn],
            puppetdb_port: 8081,
            manage_report_processor: true,
            manage_storeconfigs: true,
            strict_validation: true,
            enable_reports: true,
            restart_puppet: true
          )
        end
      end

      context 'with custom PostgreSQL settings' do
        let(:params) do
          {
            manage_puppetdb: true,
            postgres_host: 'db.example.com',
            postgres_port: 5433,
            postgres_database: 'custom_db',
            postgres_username: 'custom_user',
            postgres_password: sensitive('custom_pass')
          }
        end

        it { is_expected.to compile.with_all_deps }

        it do
          is_expected.to contain_class('puppetdb').with(
            database_host: 'db.example.com',
            database_port: 5433,
            database_name: 'custom_db',
            database_username: 'custom_user',
            database_password: 'custom_pass'
          )
        end
      end

      context 'with custom Java memory settings' do
        let(:params) do
          {
            manage_puppetdb: true,
            postgres_password: sensitive('test_password'),
            java_args: {
              '-Xmx' => '4g',
              '-Xms' => '2g'
            }
          }
        end

        it { is_expected.to compile.with_all_deps }

        it do
          is_expected.to contain_class('puppetdb').with(
            java_args: {
              '-Xmx' => '4g',
              '-Xms' => '2g'
            }
          )
        end
      end
    end
  end
end
