# frozen_string_literal: true

require 'spec_helper'

describe 'profile::puppet_agent' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      context 'with default parameters' do
        it { is_expected.to compile.with_all_deps }

        it {
          is_expected.to contain_class('puppet').with(
            agent: true,
            agent_server_hostname: 'pi.ra-home.co.uk',
            ca_server: 'pi.ra-home.co.uk',
            runinterval: 1800,
            environment: 'production'
          )
        }
      end

      context 'with custom server hostname' do
        let(:params) do
          {
            server_hostname: 'foreman01.ra-home.co.uk'
          }
        end

        it { is_expected.to compile.with_all_deps }

        it {
          is_expected.to contain_class('puppet').with(
            agent_server_hostname: 'foreman01.ra-home.co.uk'
          )
        }
      end

      context 'with custom CA server' do
        let(:params) do
          {
            ca_server: 'ca.example.com'
          }
        end

        it { is_expected.to compile.with_all_deps }

        it {
          is_expected.to contain_class('puppet').with(
            ca_server: 'ca.example.com'
          )
        }
      end

      context 'with manage_agent => false' do
        let(:params) do
          {
            manage_agent: false
          }
        end

        it { is_expected.to compile.with_all_deps }
        it { is_expected.not_to contain_class('puppet') }
      end
    end
  end
end
