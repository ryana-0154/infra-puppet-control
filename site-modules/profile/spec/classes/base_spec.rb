# frozen_string_literal: true

require 'spec_helper'

describe 'profile::base' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      context 'with default configuration' do
        it { is_expected.to compile.with_all_deps }

        it { is_expected.to contain_class('profile::dns') }
        it { is_expected.to contain_class('profile::puppet_agent') }

        # ensure_packages normalizes 'present' to 'installed'
        it { is_expected.to contain_package('vim').with_ensure('installed') }
        it { is_expected.to contain_package('curl').with_ensure('installed') }
        it { is_expected.to contain_package('wget').with_ensure('installed') }
      end
    end
  end
end
