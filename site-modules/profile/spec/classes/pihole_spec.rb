# frozen_string_literal: true

require 'spec_helper'

describe 'profile::pihole' do
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
        'fqdn' => 'pihole.example.com',
        'hostname' => 'pihole',
        'domain' => 'example.com'
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

  context 'with default parameters and password provided' do
    let(:params) do
      {
        pihole_password_hash: '$BALLOON-SHA256$v=1$test_hash'
      }
    end

    it { is_expected.to compile.with_all_deps }

    it do
      is_expected.to contain_file('/etc/pihole').with(
        ensure: 'directory',
        owner: 'root',
        group: 'root',
        mode: '0755'
      )
    end

    it do
      is_expected.to contain_file('/etc/pihole/pihole.toml').with(
        ensure: 'file',
        owner: 'root',
        group: 'root',
        mode: '0644'
      )
    end

    it do
      is_expected.to contain_file('/etc/pihole/gravity.db').with(
        ensure: 'file',
        source: 'puppet:///modules/profile/pihole/gravity.db',
        owner: 'root',
        group: 'root',
        mode: '0644'
      )
    end

    it do
      is_expected.to contain_file('/etc/pihole/custom.list').with(
        ensure: 'file',
        source: 'puppet:///modules/profile/pihole/custom_hosts',
        owner: 'root',
        group: 'root',
        mode: '0644'
      )
    end

    it do
      is_expected.to contain_exec('restart-pihole').with(
        command: 'docker restart pihole',
        refreshonly: true
      ).that_requires('File[/etc/pihole/pihole.toml]')
    end
  end

  context 'with manage_pihole disabled' do
    let(:params) { { manage_pihole: false } }

    it { is_expected.to compile.with_all_deps }
    it { is_expected.not_to contain_file('/etc/pihole') }
    it { is_expected.not_to contain_file('/etc/pihole/pihole.toml') }
  end

  context 'without password hash' do
    let(:params) { { manage_pihole: true } }

    it { is_expected.to compile.and_raise_error(/pihole_password_hash is required/) }
  end

  context 'with gravity database disabled' do
    let(:params) do
      {
        pihole_password_hash: '$BALLOON-SHA256$v=1$test_hash',
        provision_gravity_db: false
      }
    end

    it { is_expected.to compile.with_all_deps }
    it { is_expected.not_to contain_file('/etc/pihole/gravity.db') }
  end

  context 'with custom hosts disabled' do
    let(:params) do
      {
        pihole_password_hash: '$BALLOON-SHA256$v=1$test_hash',
        provision_custom_hosts: false
      }
    end

    it { is_expected.to compile.with_all_deps }
    it { is_expected.not_to contain_file('/etc/pihole/custom.list') }
  end

  context 'with restart disabled' do
    let(:params) do
      {
        pihole_password_hash: '$BALLOON-SHA256$v=1$test_hash',
        restart_on_config_change: false
      }
    end

    it { is_expected.to compile.with_all_deps }

    it do
      is_expected.to contain_file('/etc/pihole/pihole.toml').without_notify
    end
  end

  context 'with custom container name' do
    let(:params) do
      {
        pihole_password_hash: '$BALLOON-SHA256$v=1$test_hash',
        pihole_container_name: 'my-pihole'
      }
    end

    it { is_expected.to compile.with_all_deps }

    it do
      is_expected.to contain_exec('restart-pihole').with(
        command: 'docker restart my-pihole'
      )
    end
  end
end
