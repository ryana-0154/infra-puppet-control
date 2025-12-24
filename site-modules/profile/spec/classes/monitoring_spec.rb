# frozen_string_literal: true

require 'spec_helper'

describe 'profile::monitoring' do
  let(:facts) do
    {
      os: {
        'family' => 'Debian',
        'name' => 'Ubuntu',
        'release' => {
          'major' => '22',
          'minor' => '04',
          'full' => '22.04'
        }
      },
      networking: {
        'fqdn' => 'vps.ra-home.co.uk',
        'hostname' => 'vps',
        'domain' => 'ra-home.co.uk'
      },
      kernel: 'Linux',
      kernelversion: '5.15.0',
      architecture: 'x86_64',
      operatingsystem: 'Ubuntu',
      operatingsystemrelease: '22.04',
      osfamily: 'Debian',
      lsbdistcodename: 'jammy',
      lsbdistid: 'Ubuntu'
    }
  end

  context 'with default parameters' do
    it { is_expected.to compile.with_all_deps }

    it do
      is_expected.to contain_file('/opt/monitoring').with(
        ensure: 'directory',
        owner: 'root',
        group: 'root',
        mode: '0755'
      )
    end
  end

  context 'with manage_monitoring disabled' do
    let(:params) { { manage_monitoring: false } }

    it { is_expected.to compile.with_all_deps }
    it { is_expected.not_to contain_file('/opt/monitoring') }
  end

  context 'with custom monitoring directory' do
    let(:params) do
      {
        monitoring_dir: '/var/monitoring',
        monitoring_dir_owner: 'monitor',
        monitoring_dir_group: 'monitor',
        monitoring_dir_mode: '0750'
      }
    end

    it { is_expected.to compile.with_all_deps }

    it do
      is_expected.to contain_file('/var/monitoring').with(
        ensure: 'directory',
        owner: 'monitor',
        group: 'monitor',
        mode: '0750'
      )
    end
  end

  context 'with grafana enabled' do
    let(:params) { { enable_grafana: true } }

    it { is_expected.to compile.with_all_deps }

    it do
      is_expected.to contain_file('/opt/monitoring/provisioning').with(
        ensure: 'directory',
        owner: 'root',
        group: 'root',
        mode: '0755'
      )
    end

    it do
      is_expected.to contain_file('/opt/monitoring/provisioning/datasources').with(
        ensure: 'directory',
        owner: 'root',
        group: 'root',
        mode: '0755'
      )
    end

    it do
      is_expected.to contain_file('/opt/monitoring/provisioning/datasources/loki.yaml').with(
        ensure: 'file',
        owner: 'root',
        group: 'root',
        mode: '0644'
      )
    end

    it do
      is_expected.to contain_file('/opt/monitoring/provisioning/dashboards').with(
        ensure: 'directory',
        owner: 'root',
        group: 'root',
        mode: '0755'
      )
    end

    it do
      is_expected.to contain_file('/opt/monitoring/provisioning/dashboards/dashboard-provider.yaml').with(
        ensure: 'file',
        owner: 'root',
        group: 'root',
        mode: '0644'
      )
    end

    it do
      is_expected.to contain_file('/opt/monitoring/provisioning/dashboards/loki-logs-overview.json').with(
        ensure: 'file',
        owner: 'root',
        group: 'root',
        mode: '0644'
      )
    end
  end

  context 'with grafana disabled' do
    let(:params) { { enable_grafana: false } }

    it { is_expected.to compile.with_all_deps }

    it { is_expected.not_to contain_file('/opt/monitoring/provisioning') }
    it { is_expected.not_to contain_file('/opt/monitoring/provisioning/datasources') }
    it { is_expected.not_to contain_file('/opt/monitoring/provisioning/datasources/loki.yaml') }
    it { is_expected.not_to contain_file('/opt/monitoring/provisioning/dashboards') }
    it { is_expected.not_to contain_file('/opt/monitoring/provisioning/dashboards/dashboard-provider.yaml') }
    it { is_expected.not_to contain_file('/opt/monitoring/provisioning/dashboards/loki-logs-overview.json') }
  end

  context 'with Authelia SSO enabled' do
    let(:params) do
      {
        enable_authelia: true,
        domain_name: 'example.com',
        authelia_jwt_secret: 'test_jwt_secret',
        authelia_session_secret: 'test_session_secret',
        authelia_storage_encryption_key: 'test_storage_key',
        sso_users: {
          'admin' => {
            'displayname' => 'Administrator',
            'email' => 'admin@example.com',
            'password' => '$argon2id$v=19$m=65536,t=3,p=4$test',
            'groups' => ['admins']
          }
        }
      }
    end

    it { is_expected.to compile.with_all_deps }

    it do
      is_expected.to contain_file('/opt/monitoring/authelia-config.yaml').with(
        ensure: 'file',
        owner: 'root',
        group: 'root',
        mode: '0644'
      )
    end

    it do
      is_expected.to contain_file('/opt/monitoring/authelia-users.yaml').with(
        ensure: 'file',
        owner: 'root',
        group: 'root',
        mode: '0600'
      )
    end
  end

  context 'with Authelia disabled' do
    let(:params) { { enable_authelia: false } }

    it { is_expected.to compile.with_all_deps }

    it { is_expected.not_to contain_file('/opt/monitoring/authelia-config.yaml') }
    it { is_expected.not_to contain_file('/opt/monitoring/authelia-users.yaml') }
  end

  context 'with nginx proxy enabled' do
    let(:params) do
      {
        enable_nginx_proxy: true,
        domain_name: 'example.com'
      }
    end

    it { is_expected.to compile.with_all_deps }

    it do
      is_expected.to contain_file('/opt/monitoring/nginx.conf').with(
        ensure: 'file',
        owner: 'root',
        group: 'root',
        mode: '0644'
      )
    end
  end

  context 'with nginx proxy disabled' do
    let(:params) { { enable_nginx_proxy: false } }

    it { is_expected.to compile.with_all_deps }

    it { is_expected.not_to contain_file('/opt/monitoring/nginx.conf') }
  end

  context 'with docker-compose management' do
    it { is_expected.to compile.with_all_deps }

    it 'ensures docker-compose-plugin is installed' do
      is_expected.to contain_package('docker-compose-plugin').with_ensure('installed')
    end

    it 'starts docker-compose stack' do
      is_expected.to contain_exec('start-monitoring-stack').with(
        command: 'docker compose up -d',
        cwd: '/opt/monitoring'
      )
    end

    it 'restarts containers on config changes' do
      is_expected.to contain_exec('restart-monitoring-stack').with(
        command: 'docker compose up -d --force-recreate',
        cwd: '/opt/monitoring',
        refreshonly: true
      )
    end
  end

  context 'with external dashboards enabled' do
    let(:params) do
      {
        enable_external_dashboards: true,
        dashboard_repo_url: 'https://github.com/example/dashboards.git'
      }
    end

    it { is_expected.to compile.with_all_deps }

    it 'clones dashboard repository' do
      is_expected.to contain_vcsrepo('/opt/monitoring/dashboards-external').with(
        ensure: 'present',
        provider: 'git',
        source: 'https://github.com/example/dashboards.git',
        revision: 'main'
      )
    end

    it 'includes embedded dashboards by default' do
      is_expected.to contain_file('/opt/monitoring/provisioning/dashboards/loki-logs-overview.json')
    end
  end

  context 'with external dashboards and auto-update enabled' do
    let(:params) do
      {
        enable_external_dashboards: true,
        dashboard_repo_url: 'https://github.com/example/dashboards.git',
        dashboard_auto_update: true
      }
    end

    it { is_expected.to compile.with_all_deps }

    it 'clones repository with latest ensure' do
      is_expected.to contain_vcsrepo('/opt/monitoring/dashboards-external').with_ensure('latest')
    end
  end

  context 'with external dashboards only (no embedded)' do
    let(:params) do
      {
        enable_external_dashboards: true,
        dashboard_repo_url: 'https://github.com/example/dashboards.git',
        enable_embedded_dashboards: false
      }
    end

    it { is_expected.to compile.with_all_deps }

    it 'does not include embedded dashboard' do
      is_expected.not_to contain_file('/opt/monitoring/provisioning/dashboards/loki-logs-overview.json')
    end

    it 'still creates dashboard provider config' do
      is_expected.to contain_file('/opt/monitoring/provisioning/dashboards/dashboard-provider.yaml')
    end
  end

  context 'with external dashboards enabled but no URL' do
    let(:params) do
      {
        enable_external_dashboards: true
      }
    end

    it 'fails with validation error' do
      is_expected.to compile.and_raise_error(
        /dashboard_repo_url is required when enable_external_dashboards is true/
      )
    end
  end

  context 'with custom dashboard repository revision' do
    let(:params) do
      {
        enable_external_dashboards: true,
        dashboard_repo_url: 'https://github.com/example/dashboards.git',
        dashboard_repo_revision: 'v1.2.3'
      }
    end

    it { is_expected.to compile.with_all_deps }

    it 'uses custom revision' do
      is_expected.to contain_vcsrepo('/opt/monitoring/dashboards-external').with_revision('v1.2.3')
    end
  end
end
