# frozen_string_literal: true

require 'spec_helper'

describe 'profile::nginx_proxy' do
  on_supported_os.each do |os, os_facts|
    context "when on #{os}" do
      let(:facts) { os_facts }

      context 'with default parameters (manage_nginx => false)' do
        it { is_expected.to compile.with_all_deps }
        it { is_expected.not_to contain_class('nginx') }
      end

      context 'with manage_nginx => true (no vhosts)' do
        let(:params) do
          {
            manage_nginx: true
          }
        end

        it { is_expected.to compile.with_all_deps }

        it do
          is_expected.to contain_class('nginx').with(
            manage_repo: true,
            package_source: 'nginx-stable',
            confd_purge: true,
            server_purge: true
          )
        end

        it do
          is_expected.to contain_nginx__resource__server('default').with(
            listen_port: 80,
            ipv6_listen_port: 80,
            ssl: false
          )
        end
      end

      context 'with HTTP to HTTPS redirect enabled' do
        let(:params) do
          {
            manage_nginx: true,
            enable_http_redirect: true,
            proxy_vhosts: {
              'grafana' => {
                'server_name' => ['grafana.example.com'],
                'proxy' => 'http://localhost:3000'
              }
            }
          }
        end

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_nginx__resource__server('http_redirect') }
      end

      context 'with proxy virtual hosts' do
        let(:params) do
          {
            manage_nginx: true,
            proxy_vhosts: {
              'grafana' => {
                'server_name' => ['grafana.example.com'],
                'proxy' => 'http://localhost:3000'
              },
              'authelia' => {
                'server_name' => ['auth.example.com'],
                'proxy' => 'http://localhost:9091'
              }
            }
          }
        end

        it { is_expected.to compile.with_all_deps }

        it do
          is_expected.to contain_nginx__resource__server('grafana').with(
            listen_port: 443,
            ipv6_listen_port: 443,
            ssl: true,
            ssl_cert: '/etc/ssl/letsencrypt/wildcard_ra_home/fullchain.pem',
            ssl_key: '/etc/ssl/letsencrypt/wildcard_ra_home/privkey.pem',
            http2: 'on'
          )
        end

        it do
          is_expected.to contain_nginx__resource__server('authelia').with(
            listen_port: 443,
            ipv6_listen_port: 443,
            ssl: true
          )
        end
      end

      context 'with custom SSL certificate paths' do
        let(:params) do
          {
            manage_nginx: true,
            ssl_cert_path: '/custom/path/cert.pem',
            ssl_key_path: '/custom/path/key.pem',
            proxy_vhosts: {
              'test' => {
                'server_name' => ['test.example.com'],
                'proxy' => 'http://localhost:8080'
              }
            }
          }
        end

        it { is_expected.to compile.with_all_deps }

        it do
          is_expected.to contain_nginx__resource__server('test').with(
            ssl_cert: '/custom/path/cert.pem',
            ssl_key: '/custom/path/key.pem'
          )
        end
      end

      context 'with custom SSL protocols' do
        let(:params) do
          {
            manage_nginx: true,
            ssl_protocols: ['TLSv1.3'],
            proxy_vhosts: {
              'test' => {
                'server_name' => ['test.example.com'],
                'proxy' => 'http://localhost:8080'
              }
            }
          }
        end

        it { is_expected.to compile.with_all_deps }

        it do
          is_expected.to contain_nginx__resource__server('test').with(
            ssl_protocols: 'TLSv1.3'
          )
        end
      end

      context 'with HTTP redirect disabled' do
        let(:params) do
          {
            manage_nginx: true,
            enable_http_redirect: false
          }
        end

        it { is_expected.to compile.with_all_deps }
        it { is_expected.not_to contain_nginx__resource__server('http_redirect') }
      end
    end
  end
end
