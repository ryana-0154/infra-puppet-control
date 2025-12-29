# frozen_string_literal: true

require 'spec_helper'

describe 'role::foreman' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      it { is_expected.to compile.with_all_deps }

      it { is_expected.to contain_class('profile::base') }
      it { is_expected.to contain_class('profile::postgresql') }
      it { is_expected.to contain_class('profile::foreman') }
      it { is_expected.to contain_class('profile::foreman_proxy') }

      # Verify profiles are included in correct order (base first)
      it { is_expected.to contain_class('profile::base').that_comes_before('Class[profile::postgresql]') }
      it { is_expected.to contain_class('profile::postgresql').that_comes_before('Class[profile::foreman]') }
      it { is_expected.to contain_class('profile::foreman').that_comes_before('Class[profile::foreman_proxy]') }
    end
  end
end
