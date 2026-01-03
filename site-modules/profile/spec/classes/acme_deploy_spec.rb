# frozen_string_literal: true

require 'spec_helper'

describe 'profile::acme_deploy' do
  on_supported_os.each do |os, os_facts|
    context "when on #{os}" do
      let(:facts) { os_facts }

      context 'with default parameters (manage_deploy => false)' do
        it { is_expected.to compile.with_all_deps }
        it { is_expected.not_to contain_file('/etc/ssl/letsencrypt') }
        it { is_expected.not_to contain_group('ssl-cert') }
      end

      context 'with manage_deploy => true (no certificates)' do
        let(:params) do
          {
            manage_deploy: true
          }
        end

        it { is_expected.to compile.with_all_deps }

        it do
          is_expected.to contain_file('/etc/ssl/letsencrypt').with(
            ensure: 'directory',
            owner: 'root',
            group: 'root',
            mode: '0755'
          )
        end

        it do
          is_expected.to contain_group('ssl-cert').with(
            ensure: 'present',
            system: true
          )
        end
      end

      context 'with certificate deployment' do
        let(:params) do
          {
            manage_deploy: true,
            deploy_certificates: {
              'wildcard_ra_home' => {
                'user' => 'root',
                'group' => 'ssl-cert',
                'key_mode' => '0640',
                'cert_mode' => '0644',
                'post_refresh_cmd' => 'systemctl reload nginx'
              }
            }
          }
        end

        it { is_expected.to compile.with_all_deps }

        it do
          is_expected.to contain_acme__deploy('wildcard_ra_home').with(
            path: '/etc/ssl/letsencrypt/wildcard_ra_home',
            user: 'root',
            group: 'ssl-cert',
            key_mode: '0640',
            cert_mode: '0644',
            post_refresh_cmd: 'systemctl reload nginx'
          )
        end
      end

      context 'with multiple certificates' do
        let(:params) do
          {
            manage_deploy: true,
            deploy_certificates: {
              'cert1' => {},
              'cert2' => {}
            }
          }
        end

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_acme__deploy('cert1') }
        it { is_expected.to contain_acme__deploy('cert2') }
      end

      context 'with custom base certificate path' do
        let(:params) do
          {
            manage_deploy: true,
            base_cert_path: '/opt/certificates',
            deploy_certificates: {
              'test_cert' => {}
            }
          }
        end

        it { is_expected.to compile.with_all_deps }

        it do
          is_expected.to contain_file('/opt/certificates').with(
            ensure: 'directory'
          )
        end

        it do
          is_expected.to contain_acme__deploy('test_cert').with(
            path: '/opt/certificates/test_cert'
          )
        end
      end

      context 'with custom SSL group' do
        let(:params) do
          {
            manage_deploy: true,
            ssl_group: 'custom-ssl',
            deploy_certificates: {
              'test_cert' => {}
            }
          }
        end

        it { is_expected.to compile.with_all_deps }

        it do
          is_expected.to contain_group('custom-ssl').with(
            ensure: 'present',
            system: true
          )
        end

        it do
          is_expected.to contain_acme__deploy('test_cert').with(
            group: 'custom-ssl'
          )
        end
      end
    end
  end
end
