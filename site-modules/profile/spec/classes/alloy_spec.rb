# frozen_string_literal: true

require 'spec_helper'

describe 'profile::alloy' do
  let(:facts) do
    {
      os: {
        'family' => 'RedHat',
        'name' => 'Rocky',
        'release' => {
          'major' => '9',
          'minor' => '3',
          'full' => '9.3'
        }
      },
      networking: {
        'fqdn' => 'test.example.com',
        'hostname' => 'test',
        'domain' => 'example.com'
      },
      kernel: 'Linux',
      kernelversion: '5.14.0',
      architecture: 'x86_64',
      operatingsystem: 'Rocky',
      operatingsystemrelease: '9.3',
      osfamily: 'RedHat'
    }
  end

  let(:default_grafana_params) do
    {
      enable_metrics: true,
      enable_logs: true,
      grafana_cloud_metrics_url: 'https://prometheus-prod.grafana.net/api/prom/push',
      grafana_cloud_metrics_username: '123456',
      grafana_cloud_metrics_api_key: 'glc_test_metrics_key',
      grafana_cloud_logs_url: 'https://logs-prod.grafana.net/loki/api/v1/push',
      grafana_cloud_logs_username: '654321',
      grafana_cloud_logs_api_key: 'glc_test_logs_key'
    }
  end

  context 'with all required parameters' do
    let(:params) { default_grafana_params }

    it { is_expected.to compile.with_all_deps }

    it do
      is_expected.to contain_file('/opt/alloy').with(
        ensure: 'directory',
        owner: 'root',
        group: 'root',
        mode: '0755'
      )
    end

    it do
      is_expected.to contain_file('/opt/alloy/config.alloy').with(
        ensure: 'file',
        owner: 'root',
        group: 'root',
        mode: '0644'
      )
    end

    it do
      is_expected.to contain_file('/opt/alloy/docker-compose.yaml').with(
        ensure: 'file',
        owner: 'root',
        group: 'root',
        mode: '0644'
      )
    end

    it 'starts alloy container' do
      is_expected.to contain_exec('start-alloy').with(
        command: 'docker compose up -d',
        cwd: '/opt/alloy'
      )
    end

    it 'restarts alloy on config changes' do
      is_expected.to contain_exec('restart-alloy').with(
        command: 'docker compose up -d --force-recreate',
        cwd: '/opt/alloy',
        refreshonly: true
      )
    end
  end

  context 'with manage_alloy disabled' do
    let(:params) { default_grafana_params.merge(manage_alloy: false) }

    it { is_expected.to compile.with_all_deps }
    it { is_expected.not_to contain_file('/opt/alloy') }
    it { is_expected.not_to contain_file('/opt/alloy/config.alloy') }
    it { is_expected.not_to contain_file('/opt/alloy/docker-compose.yaml') }
  end

  context 'with custom alloy directory' do
    let(:params) { default_grafana_params.merge(alloy_dir: '/var/lib/alloy') }

    it { is_expected.to compile.with_all_deps }

    it do
      is_expected.to contain_file('/var/lib/alloy').with(
        ensure: 'directory'
      )
    end

    it do
      is_expected.to contain_file('/var/lib/alloy/config.alloy').with(
        ensure: 'file'
      )
    end
  end

  context 'with metrics enabled' do
    let(:params) { default_grafana_params.merge(enable_metrics: true) }

    it { is_expected.to compile.with_all_deps }

    it 'includes metrics configuration in alloy config' do
      is_expected.to contain_file('/opt/alloy/config.alloy')
        .with_content(/METRICS COLLECTION/)
        .with_content(/prometheus\.remote_write "grafana_cloud"/)
        .with_content(%r{url = "https://prometheus-prod\.grafana\.net/api/prom/push"})
    end
  end

  context 'with logs enabled' do
    let(:params) { default_grafana_params.merge(enable_logs: true) }

    it { is_expected.to compile.with_all_deps }

    it 'includes logs configuration in alloy config' do
      is_expected.to contain_file('/opt/alloy/config.alloy')
        .with_content(/LOGS COLLECTION/)
        .with_content(/loki\.write "grafana_cloud"/)
        .with_content(%r{url = "https://logs-prod\.grafana\.net/loki/api/v1/push"})
    end
  end

  context 'with node_exporter enabled' do
    let(:params) { default_grafana_params.merge(enable_node_exporter: true) }

    it { is_expected.to compile.with_all_deps }

    it 'includes node_exporter configuration' do
      is_expected.to contain_file('/opt/alloy/config.alloy')
        .with_content(/prometheus\.exporter\.unix "node"/)
        .with_content(/prometheus\.scrape "node_exporter"/)
    end
  end

  context 'with node_exporter disabled' do
    let(:params) { default_grafana_params.merge(enable_node_exporter: false) }

    it { is_expected.to compile.with_all_deps }

    it 'does not include node_exporter configuration' do
      is_expected.to contain_file('/opt/alloy/config.alloy')
        .without_content(/prometheus\.exporter\.unix "node"/)
    end
  end

  context 'with additional scrape targets' do
    let(:params) do
      default_grafana_params.merge(
        additional_scrape_targets: [
          { 'name' => 'my_app', 'address' => 'localhost:8080', 'metrics_path' => '/metrics' },
          { 'name' => 'redis', 'address' => 'localhost:9121' }
        ]
      )
    end

    it { is_expected.to compile.with_all_deps }

    it 'includes additional scrape targets in config' do
      is_expected.to contain_file('/opt/alloy/config.alloy')
        .with_content(/prometheus\.scrape "my_app"/)
        .with_content(/localhost:8080/)
        .with_content(%r{metrics_path\s*=\s*"/metrics"})
        .with_content(/prometheus\.scrape "redis"/)
        .with_content(/localhost:9121/)
    end
  end

  context 'with metrics enabled but missing credentials' do
    let(:params) do
      {
        enable_metrics: true,
        enable_logs: false,
        grafana_cloud_metrics_url: 'https://prometheus.grafana.net'
      }
    end

    it 'fails with validation error' do
      is_expected.to compile.and_raise_error(
        /grafana_cloud_metrics_url, grafana_cloud_metrics_username, and grafana_cloud_metrics_api_key are required/
      )
    end
  end

  context 'with logs enabled but missing credentials' do
    let(:params) do
      {
        enable_metrics: false,
        enable_logs: true,
        grafana_cloud_logs_url: 'https://logs.grafana.net'
      }
    end

    it 'fails with validation error' do
      is_expected.to compile.and_raise_error(
        /grafana_cloud_logs_url, grafana_cloud_logs_username, and grafana_cloud_logs_api_key are required/
      )
    end
  end

  context 'with both metrics and logs disabled' do
    let(:params) do
      {
        enable_metrics: false,
        enable_logs: false
      }
    end

    it { is_expected.to compile.with_all_deps }

    it 'creates minimal config' do
      is_expected.to contain_file('/opt/alloy/config.alloy')
        .without_content(/METRICS COLLECTION/)
        .without_content(/LOGS COLLECTION/)
    end
  end

  context 'with custom bind address and port' do
    let(:params) do
      default_grafana_params.merge(
        bind_address: '10.10.10.1',
        alloy_http_port: 9999
      )
    end

    it { is_expected.to compile.with_all_deps }

    it 'uses custom bind address in docker-compose' do
      is_expected.to contain_file('/opt/alloy/docker-compose.yaml')
        .with_content(/--server\.http\.listen-addr=10\.10\.10\.1:9999/)
    end
  end

  context 'with custom scrape interval' do
    let(:params) { default_grafana_params.merge(scrape_interval: '30s') }

    it { is_expected.to compile.with_all_deps }

    it 'uses custom scrape interval' do
      is_expected.to contain_file('/opt/alloy/config.alloy')
        .with_content(/scrape_interval = "30s"/)
    end
  end

  context 'includes hostname in config' do
    let(:params) { default_grafana_params }

    it 'uses fqdn as hostname' do
      is_expected.to contain_file('/opt/alloy/config.alloy')
        .with_content(/host\s*=\s*"test\.example\.com"/)
    end
  end
end
