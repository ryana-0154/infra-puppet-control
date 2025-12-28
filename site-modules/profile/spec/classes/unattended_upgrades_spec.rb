# frozen_string_literal: true

require 'spec_helper'

describe 'profile::unattended_upgrades' do
  on_supported_os({
                    supported_os: [
                      { 'operatingsystem' => 'Rocky', 'operatingsystemrelease' => %w[8 9] },
                      { 'operatingsystem' => 'AlmaLinux', 'operatingsystemrelease' => %w[8 9] },
                      { 'operatingsystem' => 'RedHat', 'operatingsystemrelease' => %w[7 8 9] },
                      { 'operatingsystem' => 'Debian', 'operatingsystemrelease' => %w[10 11 12] },
                      { 'operatingsystem' => 'Ubuntu', 'operatingsystemrelease' => ['20.04', '22.04'] }
                    ],
                    facterversion: '4.4'
                  }).each do |os, os_facts|
    context "when on #{os}" do
      let(:facts) { os_facts }

      context 'with default parameters' do
        it { is_expected.to compile.with_all_deps }
        it { is_expected.not_to contain_class('apt') }
        it { is_expected.not_to contain_class('apt::unattended_upgrades') }
      end

      context 'with manage_unattended_upgrades enabled' do
        let(:params) do
          {
            manage_unattended_upgrades: true
          }
        end

        it { is_expected.to compile.with_all_deps }

        # unattended-upgrades is Debian-specific
        if os_facts[:os]['family'] == 'Debian'
          it { is_expected.to contain_package('unattended-upgrades').with_ensure('installed') }
          it { is_expected.to contain_package('apt-listchanges').with_ensure('installed') }

          it {
            is_expected.to contain_file('/etc/apt/apt.conf.d/50unattended-upgrades').with(
              ensure: 'file',
              owner: 'root',
              group: 'root',
              mode: '0644'
            )
          }

          it {
            is_expected.to contain_file('/etc/apt/apt.conf.d/20auto-upgrades').with(
              ensure: 'file',
              owner: 'root',
              group: 'root',
              mode: '0644'
            )
          }
        else
          it { is_expected.not_to contain_package('unattended-upgrades') }
          it { is_expected.not_to contain_package('apt-listchanges') }
          it { is_expected.not_to contain_file('/etc/apt/apt.conf.d/50unattended-upgrades') }
          it { is_expected.not_to contain_file('/etc/apt/apt.conf.d/20auto-upgrades') }
        end
      end

      context 'with automatic_reboot enabled' do
        let(:params) do
          {
            manage_unattended_upgrades: true,
            automatic_reboot: true,
            automatic_reboot_time: '03:00'
          }
        end

        it { is_expected.to compile.with_all_deps }

        if os_facts[:os]['family'] == 'Debian'
          it { is_expected.to contain_package('unattended-upgrades') }
          it { is_expected.to contain_file('/etc/apt/apt.conf.d/50unattended-upgrades') }
          it { is_expected.to contain_file('/etc/apt/apt.conf.d/20auto-upgrades') }
        end
      end

      context 'with email notifications' do
        let(:params) do
          {
            manage_unattended_upgrades: true,
            email: 'admin@example.com',
            mail_only_on_error: false
          }
        end

        it { is_expected.to compile.with_all_deps }

        if os_facts[:os]['family'] == 'Debian'
          it { is_expected.to contain_package('unattended-upgrades') }
          it { is_expected.to contain_file('/etc/apt/apt.conf.d/50unattended-upgrades') }
        end
      end

      context 'with custom origins' do
        let(:params) do
          {
            manage_unattended_upgrades: true,
            origins: [
              '${distro_id}:${distro_codename}-security',
              '${distro_id}:${distro_codename}-updates'
            ]
          }
        end

        it { is_expected.to compile.with_all_deps }

        if os_facts[:os]['family'] == 'Debian'
          it { is_expected.to contain_package('unattended-upgrades') }
          it { is_expected.to contain_file('/etc/apt/apt.conf.d/50unattended-upgrades') }
        end
      end

      context 'with package blacklist' do
        let(:params) do
          {
            manage_unattended_upgrades: true,
            blacklist: ['linux-image-*', 'docker-ce']
          }
        end

        it { is_expected.to compile.with_all_deps }

        if os_facts[:os]['family'] == 'Debian'
          it { is_expected.to contain_package('unattended-upgrades') }
          it { is_expected.to contain_file('/etc/apt/apt.conf.d/50unattended-upgrades') }
        end
      end
    end
  end
end
