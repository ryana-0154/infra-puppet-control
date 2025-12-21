# frozen_string_literal: true

require 'spec_helper'

describe 'profile::otel_collector' do
  on_supported_os.each do |os, os_facts|
    context "when running on #{os}" do
      let(:facts) { os_facts }

      context 'with default parameters' do
        it { is_expected.to compile.with_all_deps }

        it 'creates OTEL directory structure' do
          is_expected.to contain_file('/opt/otel').with(
            ensure: 'directory',
            mode: '0755'
          )
          is_expected.to contain_file('/opt/otel/config').with(
            ensure: 'directory'
          )
          is_expected.to contain_file('/opt/otel/dashboards').with(
            ensure: 'directory'
          )
        end

        it 'creates OTEL collector configuration' do
          is_expected.to contain_file('/opt/otel/config/otel-collector-config.yaml').with(
            ensure: 'file',
            mode: '0644'
          )
        end

        it 'creates Docker Compose file' do
          is_expected.to contain_file('/opt/otel/docker-compose.yaml').with(
            ensure: 'file',
            mode: '0644'
          )
        end

        it 'creates environment file' do
          is_expected.to contain_file('/opt/otel/.env').with(
            ensure: 'file',
            mode: '0644'
          )
        end

        it 'creates systemd service' do
          is_expected.to contain_file('/etc/systemd/system/otel-collector.service').with(
            ensure: 'file',
            mode: '0644'
          )
        end

        it 'enables and starts OTEL collector service' do
          is_expected.to contain_service('otel-collector').with(
            ensure: 'running',
            enable: true
          )
        end

        it 'creates Grafana dashboards by default' do
          is_expected.to contain_file('/opt/otel/dashboards/claude-code-overview.json').with(
            ensure: 'file',
            mode: '0644'
          )
          is_expected.to contain_file('/opt/otel/dashboards/claude-code-costs.json').with(
            ensure: 'file',
            mode: '0644'
          )
        end

        it 'reloads systemd daemon' do
          is_expected.to contain_exec('systemctl-daemon-reload-otel').with(
            command: '/bin/systemctl daemon-reload',
            refreshonly: true
          )
        end
      end

      context 'with custom directory' do
        let(:params) do
          {
            'otel_dir' => '/custom/otel/path'
          }
        end

        it { is_expected.to compile.with_all_deps }

        it 'uses custom directory' do
          is_expected.to contain_file('/custom/otel/path').with(
            ensure: 'directory'
          )
        end
      end

      context 'with custom ports' do
        let(:params) do
          {
            'otel_grpc_port' => 14_317,
            'otel_http_port' => 14_318,
            'otel_prometheus_port' => 18_889
          }
        end

        it { is_expected.to compile.with_all_deps }

        it 'creates configuration with custom ports' do
          is_expected.to contain_file('/opt/otel/config/otel-collector-config.yaml')
        end
      end

      context 'with Grafana dashboards disabled' do
        let(:params) do
          {
            'enable_grafana_dashboards' => false
          }
        end

        it { is_expected.to compile.with_all_deps }

        it 'does not create Grafana dashboards' do
          is_expected.not_to contain_file('/opt/otel/dashboards/claude-code-overview.json')
          is_expected.not_to contain_file('/opt/otel/dashboards/claude-code-costs.json')
        end
      end

      context 'with OTEL collector disabled' do
        let(:params) do
          {
            'manage_otel_collector' => false
          }
        end

        it { is_expected.to compile.with_all_deps }

        it 'does not create any OTEL resources' do
          is_expected.not_to contain_file('/opt/otel')
          is_expected.not_to contain_service('otel-collector')
        end
      end
    end
  end
end
