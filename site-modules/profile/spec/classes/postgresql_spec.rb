# frozen_string_literal: true

require 'spec_helper'

describe 'profile::postgresql' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      context 'with default parameters' do
        it { is_expected.to compile.with_all_deps }
        it { is_expected.not_to contain_class('postgresql::server') }
      end

      context 'with manage_postgresql => true' do
        let(:params) do
          {
            manage_postgresql: true
          }
        end

        it { is_expected.to compile.with_all_deps }

        it {
          is_expected.to contain_class('postgresql::server').with(
            listen_addresses: 'localhost',
            port: 5432,
            postgres_version: '13'
          )
        }

        context 'with custom postgres_version' do
          let(:params) do
            super().merge(
              postgres_version: '15'
            )
          end

          it {
            is_expected.to contain_class('postgresql::server').with(
              postgres_version: '15'
            )
          }
        end

        context 'with custom port and listen_addresses' do
          let(:params) do
            super().merge(
              port: 5433,
              listen_addresses: '0.0.0.0'
            )
          end

          it {
            is_expected.to contain_class('postgresql::server').with(
              port: 5433,
              listen_addresses: '0.0.0.0'
            )
          }
        end

        context 'with databases configured' do
          let(:params) do
            super().merge(
              databases: {
                'testdb' => {
                  'owner' => 'testuser',
                  'encoding' => 'UTF8'
                }
              }
            )
          end

          it { is_expected.to compile.with_all_deps }
          it { is_expected.to contain_postgresql__server__db('testdb') }
        end

        context 'with database_users configured' do
          let(:params) do
            super().merge(
              database_users: {
                'testuser' => {
                  'password_hash' => 'md5hashed'
                }
              }
            )
          end

          it { is_expected.to compile.with_all_deps }
          it { is_expected.to contain_postgresql__server__role('testuser') }
        end

        context 'with database_grants configured' do
          let(:params) do
            super().merge(
              database_grants: {
                'testgrant' => {
                  'privilege' => 'ALL',
                  'db' => 'testdb',
                  'role' => 'testuser'
                }
              }
            )
          end

          it { is_expected.to compile.with_all_deps }
          it { is_expected.to contain_postgresql__server__database_grant('testgrant') }
        end

        context 'with firewall management enabled' do
          let(:params) do
            super().merge(
              manage_firewall: true,
              allowed_sources: ['192.168.1.10', '10.0.0.0/24']
            )
          end

          it { is_expected.to compile.with_all_deps }
          it { is_expected.to contain_firewall('100 allow PostgreSQL from 192.168.1.10') }
          it { is_expected.to contain_firewall('100 allow PostgreSQL from 10.0.0.0/24') }
        end

        context 'with firewall disabled but sources defined' do
          let(:params) do
            super().merge(
              manage_firewall: false,
              allowed_sources: ['192.168.1.10']
            )
          end

          it { is_expected.to compile.with_all_deps }
          it { is_expected.not_to contain_firewall('100 allow PostgreSQL from 192.168.1.10') }
        end
      end
    end
  end
end
