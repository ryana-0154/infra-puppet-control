# frozen_string_literal: true

require 'spec_helper'

describe 'profile::dns' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      context 'with default parameters' do
        it { is_expected.to compile.with_all_deps }

        it {
          is_expected.to contain_file('/etc/resolv.conf').with(
            ensure: 'file',
            owner: 'root',
            group: 'root',
            mode: '0644'
          )
        }

        it {
          is_expected.to contain_file('/etc/resolv.conf')
            .with_content(/nameserver 10\.10\.10\.1/)
        }

        it {
          is_expected.to contain_file('/etc/resolv.conf')
            .with_content(/search ra-home\.co\.uk/)
        }
      end

      context 'with custom nameservers' do
        let(:params) do
          {
            nameservers: ['8.8.8.8', '8.8.4.4']
          }
        end

        it { is_expected.to compile.with_all_deps }

        it {
          is_expected.to contain_file('/etc/resolv.conf')
            .with_content(/nameserver 8\.8\.8\.8/)
            .with_content(/nameserver 8\.8\.4\.4/)
        }
      end

      context 'with manage_resolv => false' do
        let(:params) do
          {
            manage_resolv: false
          }
        end

        it { is_expected.to compile.with_all_deps }
        it { is_expected.not_to contain_file('/etc/resolv.conf') }
      end
    end
  end
end
