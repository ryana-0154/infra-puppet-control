# frozen_string_literal: true

require 'spec_helper'

describe 'profile::ntp' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      context 'with default parameters' do
        it { is_expected.to compile.with_all_deps }

        it {
          is_expected.to contain_class('ntp').with(
            servers: ['0.pool.ntp.org', '1.pool.ntp.org', '2.pool.ntp.org', '3.pool.ntp.org'],
            service_enable: true,
            service_ensure: 'running'
          )
        }
      end

      context 'with custom servers' do
        let(:params) do
          {
            servers: ['time.google.com', 'time.cloudflare.com']
          }
        end

        it { is_expected.to compile.with_all_deps }

        it {
          is_expected.to contain_class('ntp').with(
            servers: ['time.google.com', 'time.cloudflare.com']
          )
        }
      end

      context 'with manage_ntp => false' do
        let(:params) do
          {
            manage_ntp: false
          }
        end

        it { is_expected.to compile.with_all_deps }
        it { is_expected.not_to contain_class('ntp') }
      end

      context 'with service disabled' do
        let(:params) do
          {
            service_enable: false,
            service_ensure: 'stopped'
          }
        end

        it { is_expected.to compile.with_all_deps }

        it {
          is_expected.to contain_class('ntp').with(
            service_enable: false,
            service_ensure: 'stopped'
          )
        }
      end
    end
  end
end
