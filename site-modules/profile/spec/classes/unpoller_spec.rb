# frozen_string_literal: true

require 'spec_helper'

describe 'profile::unpoller' do
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

  let(:default_params) do
    {
      manage_unpoller: true,
      unpoller_url: 'https://10.10.10.2',
      unpoller_user: 'unifipoller',
      unpoller_pass: 'test_password'
    }
  end

  context 'with default parameters (disabled)' do
    it { is_expected.to compile.with_all_deps }
    it { is_expected.not_to contain_file('/opt/unpoller') }
    it { is_expected.not_to contain_file('/opt/unpoller/docker-compose.yaml') }
  end

  context 'with manage_unpoller enabled' do
    let(:params) { default_params }

    it { is_expected.to compile.with_all_deps }

    it do
      is_expected.to contain_file('/opt/unpoller').with(
        ensure: 'directory',
        owner: 'root',
        group: 'root',
        mode: '0755'
      )
    end

    it do
      is_expected.to contain_file('/opt/unpoller/docker-compose.yaml').with(
        ensure: 'file',
        owner: 'root',
        group: 'root',
        mode: '0644'
      )
    end

    it 'includes UniFi controller URL in docker-compose' do
      is_expected.to contain_file('/opt/unpoller/docker-compose.yaml')
        .with_content(%r{UP_UNIFI_DEFAULT_URL: "https://10\.10\.10\.2"})
    end

    it 'includes UniFi user in docker-compose' do
      is_expected.to contain_file('/opt/unpoller/docker-compose.yaml')
        .with_content(/UP_UNIFI_DEFAULT_USER: "unifipoller"/)
    end

    it 'starts unpoller container' do
      is_expected.to contain_exec('start-unpoller').with(
        command: 'docker compose up -d',
        cwd: '/opt/unpoller'
      )
    end

    it 'restarts unpoller on config changes' do
      is_expected.to contain_exec('restart-unpoller').with(
        command: 'docker compose up -d --force-recreate',
        cwd: '/opt/unpoller',
        refreshonly: true
      )
    end
  end

  context 'with custom directory' do
    let(:params) { default_params.merge(unpoller_dir: '/var/lib/unpoller') }

    it { is_expected.to compile.with_all_deps }

    it do
      is_expected.to contain_file('/var/lib/unpoller').with(
        ensure: 'directory'
      )
    end

    it do
      is_expected.to contain_file('/var/lib/unpoller/docker-compose.yaml').with(
        ensure: 'file'
      )
    end
  end

  context 'with custom bind address and port' do
    let(:params) do
      default_params.merge(
        bind_address: '10.10.10.5',
        unpoller_port: 9999
      )
    end

    it { is_expected.to compile.with_all_deps }

    it 'uses custom bind address and port in docker-compose' do
      is_expected.to contain_file('/opt/unpoller/docker-compose.yaml')
        .with_content(/- "10\.10\.10\.5:9999:9130"/)
    end
  end

  context 'with DPI enabled' do
    let(:params) { default_params.merge(unpoller_save_dpi: true) }

    it { is_expected.to compile.with_all_deps }

    it 'enables DPI in docker-compose' do
      is_expected.to contain_file('/opt/unpoller/docker-compose.yaml')
        .with_content(/UP_UNIFI_DEFAULT_SAVE_DPI: "true"/)
    end
  end

  context 'with SSL verification enabled' do
    let(:params) { default_params.merge(unpoller_verify_ssl: true) }

    it { is_expected.to compile.with_all_deps }

    it 'enables SSL verification in docker-compose' do
      is_expected.to contain_file('/opt/unpoller/docker-compose.yaml')
        .with_content(/UP_UNIFI_DEFAULT_VERIFY_SSL: "true"/)
    end
  end

  context 'with custom sites' do
    let(:params) { default_params.merge(unpoller_sites: %w[default office]) }

    it { is_expected.to compile.with_all_deps }

    it 'includes sites in docker-compose' do
      is_expected.to contain_file('/opt/unpoller/docker-compose.yaml')
        .with_content(/- "default"/)
        .with_content(/- "office"/)
    end
  end

  context 'with manage_unpoller enabled but missing credentials' do
    let(:params) do
      {
        manage_unpoller: true,
        unpoller_url: 'https://10.10.10.2'
      }
    end

    it 'fails with validation error' do
      is_expected.to compile.and_raise_error(
        /unpoller_url, unpoller_user, and unpoller_pass are required/
      )
    end
  end

  context 'with sensitive password' do
    let(:params) do
      {
        manage_unpoller: true,
        unpoller_url: 'https://10.10.10.2',
        unpoller_user: 'unifipoller',
        unpoller_pass: sensitive('secret_password')
      }
    end

    it { is_expected.to compile.with_all_deps }
  end
end
