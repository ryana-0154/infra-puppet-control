# frozen_string_literal: true

require 'spec_helper'

describe 'profile::base' do
  on_supported_os.each do |os, os_facts|
    context "when on #{os}" do
      let(:facts) { os_facts }

      context 'with default parameters' do
        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_class('ntp') }
        it { is_expected.to contain_class('firewall') }
        it { is_expected.to contain_package('vim').with_ensure('present') }
        it { is_expected.to contain_package('curl').with_ensure('present') }
        it { is_expected.to contain_package('wget').with_ensure('present') }
      end

      context 'with manage_ntp disabled' do
        let(:params) { { manage_ntp: false } }

        it { is_expected.to compile.with_all_deps }
        it { is_expected.not_to contain_class('ntp') }
      end

      context 'with manage_firewall disabled' do
        let(:params) { { manage_firewall: false } }

        it { is_expected.to compile.with_all_deps }
        it { is_expected.not_to contain_class('firewall') }
      end

      context 'with manage_fail2ban enabled' do
        let(:params) { { manage_fail2ban: true } }

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_class('profile::fail2ban') }
      end

      context 'with manage_fail2ban disabled' do
        let(:params) { { manage_fail2ban: false } }

        it { is_expected.to compile.with_all_deps }
        it { is_expected.not_to contain_class('profile::fail2ban') }
      end

      context 'with manage_unattended_upgrades enabled' do
        let(:params) { { manage_unattended_upgrades: true } }

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_class('profile::unattended_upgrades') }
      end

      context 'with manage_unattended_upgrades disabled' do
        let(:params) { { manage_unattended_upgrades: false } }

        it { is_expected.to compile.with_all_deps }
        it { is_expected.not_to contain_class('profile::unattended_upgrades') }
      end

      context 'with manage_ssh_hardening enabled' do
        let(:params) { { manage_ssh_hardening: true } }

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_class('profile::ssh_hardening') }
      end

      context 'with manage_ssh_hardening disabled' do
        let(:params) { { manage_ssh_hardening: false } }

        it { is_expected.to compile.with_all_deps }
        it { is_expected.not_to contain_class('profile::ssh_hardening') }
      end
    end
  end
end
