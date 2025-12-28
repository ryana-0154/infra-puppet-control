# frozen_string_literal: true

require 'spec_helper'

describe 'profile::unattended_upgrades' do
  on_supported_os.each do |os, os_facts|
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

        it {
          is_expected.to contain_class('apt').with(
            update: { 'frequency' => 'daily' }
          )
        }

        it {
          is_expected.to contain_class('apt::unattended_upgrades').with(
            auto_fix_interrupted_dpkg: true,
            enable: true,
            update: 1,
            download_upgradeable: true,
            auto_clean_interval: 7,
            mail_only_on_error: true,
            remove_unused_kernel_packages: true,
            remove_unused_dependencies: true,
            automatic_reboot: false
          )
        }
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

        it {
          is_expected.to contain_class('apt::unattended_upgrades').with(
            automatic_reboot: true,
            automatic_reboot_time: '03:00'
          )
        }
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

        it {
          is_expected.to contain_class('apt::unattended_upgrades').with(
            mail: 'admin@example.com',
            mail_only_on_error: false
          )
        }
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

        it {
          is_expected.to contain_class('apt::unattended_upgrades').with(
            origins: [
              '${distro_id}:${distro_codename}-security',
              '${distro_id}:${distro_codename}-updates'
            ]
          )
        }
      end

      context 'with package blacklist' do
        let(:params) do
          {
            manage_unattended_upgrades: true,
            blacklist: ['linux-image-*', 'docker-ce']
          }
        end

        it { is_expected.to compile.with_all_deps }

        it {
          is_expected.to contain_class('apt::unattended_upgrades').with(
            blacklist: ['linux-image-*', 'docker-ce']
          )
        }
      end
    end
  end
end
