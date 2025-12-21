# frozen_string_literal: true

require 'spec_helper'

describe 'profile::monitoring' do
  on_supported_os.each do |os, os_facts|
    context "when running on #{os}" do
      let(:facts) { os_facts }

      context 'when docker-compose is configured' do
        let(:params) do
          {
            'manage_monitoring' => true,
            'monitoring_dir' => '/opt/monitoring',
            'monitoring_ip' => '10.10.10.1',
            'prometheus_port' => 9090,
            'grafana_port' => 3000,
            'enable_prometheus' => true,
            'enable_grafana' => true,
            'enable_pihole_exporter' => true,
            'pihole_hostname' => '10.10.10.1',
            'grafana_admin_password' => 'secret123',
            'pihole_password' => 'piholesecret'
          }
        end

        it { is_expected.to compile.with_all_deps }

        it {
          is_expected.to contain_file('/opt/monitoring/docker-compose.yaml')
            .with_ensure('file')
            .with_mode('0644')
        }

        it 'creates docker-compose.yaml with correct prometheus config' do
          content = catalogue.resource('file', '/opt/monitoring/docker-compose.yaml')[:content]
          expect(content).to match(/prometheus:/)
          expect(content).to match(/--web.listen-address=10\.10\.10\.1:9090/)
        end

        it 'creates docker-compose.yaml with correct grafana config' do
          content = catalogue.resource('file', '/opt/monitoring/docker-compose.yaml')[:content]
          expect(content).to match(/grafana:/)
          expect(content).to match(/GF_SERVER_HTTP_ADDR=10\.10\.10\.1/)
          expect(content).to match(/GF_SERVER_HTTP_PORT=3000/)
        end

        it 'creates secrets directory when secrets are defined' do
          is_expected.to contain_file('/opt/monitoring/secrets')
            .with_ensure('directory')
            .with_mode('0700')
        end

        it 'creates grafana admin password secret file' do
          is_expected.to contain_file('/opt/monitoring/secrets/grafana_admin_password')
            .with_ensure('file')
            .with_mode('0600')
            .with_content('secret123')
        end
      end

      context 'when services are disabled' do
        let(:params) do
          {
            'enable_prometheus' => false,
            'enable_grafana' => false,
            'enable_loki' => false
          }
        end

        it 'does not include disabled services in docker-compose' do
          content = catalogue.resource('file', '/opt/monitoring/docker-compose.yaml')[:content]
          expect(content).not_to match(/^\s*prometheus:/)
          expect(content).not_to match(/^\s*grafana:/)
          expect(content).not_to match(/^\s*loki:/)
        end
      end

      context 'without secrets' do
        let(:params) do
          {
            'grafana_admin_password' => nil,
            'pihole_api_token' => nil
          }
        end

        it { is_expected.not_to contain_file('/opt/monitoring/secrets') }
        it { is_expected.not_to contain_file('/opt/monitoring/secrets/grafana_admin_password') }
        it { is_expected.not_to contain_file('/opt/monitoring/secrets/pihole_api_token') }
      end
    end
  end
end
