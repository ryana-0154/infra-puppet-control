# frozen_string_literal: true

require 'spec_helper'

describe 'profile::foreman_proxy' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      context 'with default parameters' do
        it { is_expected.to compile.with_all_deps }
        it { is_expected.not_to contain_class('foreman_proxy') }
      end

      context 'with manage_proxy => true and required OAuth credentials' do
        let(:params) do
          {
            manage_proxy: true,
            oauth_consumer_key: sensitive('test_consumer_key'),
            oauth_consumer_secret: sensitive('test_consumer_secret')
          }
        end

        it { is_expected.to compile.with_all_deps }

        it { is_expected.to contain_class('foreman_proxy') }
        it { is_expected.to contain_service('foreman-proxy').with_ensure('running') }
        it { is_expected.to contain_service('foreman-proxy').with_enable(true) }

        context 'with default OAuth credentials (should fail)' do
          let(:params) do
            {
              manage_proxy: true
            }
          end

          it { is_expected.to compile.and_raise_error(/oauth_consumer_key must be set/) }
        end

        context 'with DNS management enabled' do
          let(:params) do
            super().merge(
              manage_dns: true,
              dns_provider: 'nsupdate',
              dns_server: '10.10.10.1'
            )
          end

          it { is_expected.to compile.with_all_deps }

          it {
            is_expected.to contain_class('foreman_proxy').with(
              dns: true,
              dns_provider: 'nsupdate',
              dns_server: '10.10.10.1'
            )
          }
        end

        context 'with DHCP management enabled' do
          let(:params) do
            super().merge(
              manage_dhcp: true
            )
          end

          it { is_expected.to compile.with_all_deps }
          it { is_expected.to contain_class('foreman_proxy').with_dhcp(true) }
        end

        context 'with TFTP management enabled' do
          let(:params) do
            super().merge(
              manage_tftp: true
            )
          end

          it { is_expected.to compile.with_all_deps }
          it { is_expected.to contain_class('foreman_proxy').with_tftp(true) }
        end

        context 'with Puppet management disabled' do
          let(:params) do
            super().merge(
              manage_puppet: false
            )
          end

          it { is_expected.to compile.with_all_deps }
          it { is_expected.to contain_class('foreman_proxy').with_puppet(false) }
        end

        context 'with custom foreman_base_url' do
          let(:params) do
            super().merge(
              foreman_base_url: 'https://foreman.example.com'
            )
          end

          it { is_expected.to compile.with_all_deps }

          it {
            is_expected.to contain_class('foreman_proxy').with(
              foreman_base_url: 'https://foreman.example.com'
            )
          }
        end
      end
    end
  end
end
