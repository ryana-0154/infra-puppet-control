# frozen_string_literal: true

require 'spec_helper'

describe 'profile::base' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
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
    end
  end
end
