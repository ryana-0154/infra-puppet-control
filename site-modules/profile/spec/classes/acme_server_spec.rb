# frozen_string_literal: true

require 'spec_helper'

describe 'profile::acme_server' do
  on_supported_os.each do |os, os_facts|
    context "when on #{os}" do
      let(:facts) { os_facts }

      context 'with default parameters (manage_acme => false)' do
        it { is_expected.to compile.with_all_deps }
        it { is_expected.not_to contain_class('acme') }
      end

      context 'with manage_acme => true and staging CA' do
        let(:params) do
          {
            manage_acme: true,
            use_staging: true,
            contact_email: 'admin@example.com',
            profiles: {
              'cloudflare_dns01' => {
                'challengetype' => 'dns-01',
                'hook' => 'dns_cf',
                'env' => {
                  'CF_Token' => 'test_token'
                }
              }
            }
          }
        end

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_class('acme') }

        it do
          is_expected.to contain_class('acme').with(
            acme_host: os_facts[:networking][:fqdn],
            ca_url: 'https://acme-staging-v02.api.letsencrypt.org/directory',
            email: 'admin@example.com'
          )
        end

        it do
          is_expected.to contain_cron('acme_renewal').with(
            command: %r{/root/\.acme\.sh/acme\.sh --cron},
            user: 'root',
            hour: 2,
            minute: 0
          )
        end
      end

      context 'with production CA (use_staging => false)' do
        let(:params) do
          {
            manage_acme: true,
            use_staging: false,
            contact_email: 'admin@example.com',
            profiles: {}
          }
        end

        it { is_expected.to compile.with_all_deps }

        it do
          is_expected.to contain_class('acme').with(
            ca_url: 'https://acme-v02.api.letsencrypt.org/directory'
          )
        end
      end

      context 'with certificate requests' do
        let(:params) do
          {
            manage_acme: true,
            use_staging: true,
            contact_email: 'admin@example.com',
            certificates: {
              'wildcard_example' => {
                'use_profile' => 'cloudflare_dns01',
                'domain' => '*.example.com'
              },
              'single_example' => {
                'use_profile' => 'cloudflare_dns01',
                'domain' => 'www.example.com'
              }
            }
          }
        end

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_acme__certificate('wildcard_example') }
        it { is_expected.to contain_acme__certificate('single_example') }
      end

      context 'with custom renewal cron hour' do
        let(:params) do
          {
            manage_acme: true,
            use_staging: true,
            contact_email: 'admin@example.com',
            renew_cron_hour: 3
          }
        end

        it { is_expected.to compile.with_all_deps }

        it do
          is_expected.to contain_cron('acme_renewal').with(
            hour: 3
          )
        end
      end

      context 'production without contact_email should fail' do
        let(:params) do
          {
            manage_acme: true,
            use_staging: false
          }
        end

        it do
          is_expected.to compile.and_raise_error(/contact_email is required/)
        end
      end
    end
  end
end
