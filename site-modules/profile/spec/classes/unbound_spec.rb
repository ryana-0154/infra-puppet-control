# frozen_string_literal: true

require 'spec_helper'

describe 'profile::unbound' do
  on_supported_os.each do |os, os_facts|
    context "with #{os}" do
      let(:facts) { os_facts }

      context 'with manage_unbound => false' do
        let(:params) do
          {
            manage_unbound: false
          }
        end

        it { is_expected.to compile.with_all_deps }
        it { is_expected.not_to contain_package('unbound') }
        it { is_expected.not_to contain_service('unbound') }
      end

      context 'with manage_unbound => true' do
        let(:params) do
          {
            manage_unbound: true
          }
        end

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_package('unbound') }

        it {
          is_expected.to contain_file('/etc/unbound').with(
            ensure: 'directory',
            owner: 'root',
            group: 'root',
            mode: '0755'
          )
        }

        it {
          is_expected.to contain_file('/etc/unbound/unbound.conf.d').with(
            ensure: 'directory',
            owner: 'root',
            group: 'root',
            mode: '0755'
          )
        }

        it {
          is_expected.to contain_file('/var/log/unbound').with(
            ensure: 'directory',
            owner: 'unbound',
            group: 'unbound',
            mode: '0755'
          )
        }

        it {
          is_expected.to contain_file('/etc/unbound/unbound.conf').with(
            ensure: 'file',
            owner: 'root',
            group: 'root',
            mode: '0644'
          ).that_notifies('Service[unbound]')
        }

        it {
          is_expected.to contain_file('/etc/unbound/unbound.conf.d/pi-hole.conf').with(
            ensure: 'file',
            owner: 'root',
            group: 'root',
            mode: '0644'
          ).that_notifies('Service[unbound]')
        }

        it {
          is_expected.to contain_file('/etc/unbound/unbound.conf.d/remote-control.conf').with(
            ensure: 'file',
            owner: 'root',
            group: 'root',
            mode: '0644'
          ).that_notifies('Service[unbound]')
        }

        it {
          is_expected.to contain_file('/etc/unbound/unbound.conf.d/root-auto-trust-anchor-file.conf').with(
            ensure: 'file',
            owner: 'root',
            group: 'root',
            mode: '0644'
          ).that_notifies('Service[unbound]')
        }

        it {
          is_expected.to contain_service('unbound').with(
            ensure: 'running',
            enable: true
          )
        }
      end

      context 'with custom parameters' do
        let(:params) do
          {
            manage_unbound: true,
            listen_port: 53,
            num_threads: 2,
            enable_ipv6: true
          }
        end

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_package('unbound') }
        it { is_expected.to contain_service('unbound') }
      end
    end
  end
end
