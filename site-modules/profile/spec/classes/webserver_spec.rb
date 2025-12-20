# frozen_string_literal: true

require 'spec_helper'

describe 'profile::webserver' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      context 'with default parameters' do
        it { is_expected.to compile.with_all_deps }

        it {
          is_expected.to contain_file('/var/www/html').with(
            ensure: 'directory',
            owner: 'root',
            group: 'root',
            mode: '0755',
          )
        }
      end

      context 'with custom document_root' do
        let(:params) { { document_root: '/srv/www' } }

        it { is_expected.to compile.with_all_deps }

        it {
          is_expected.to contain_file('/srv/www').with(
            ensure: 'directory',
          )
        }
      end
    end
  end
end
