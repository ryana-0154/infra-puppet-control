# frozen_string_literal: true

require 'spec_helper'

describe 'profile::pihole_native' do
  on_supported_os.each do |os, os_facts|
    context "when on #{os}" do
      let(:facts) { os_facts }

      context 'with default parameters' do
        it { is_expected.to compile.with_all_deps }
        it { is_expected.not_to contain_file('/etc/pihole') }
      end

      context 'with manage_pihole enabled' do
        let(:params) do
          {
            manage_pihole: true,
            pihole_interface: 'wg0',
            pihole_ipv4_address: '10.10.10.1/24',
            pihole_webpassword: 'test_password'
          }
        end

        it { is_expected.to compile.with_all_deps }

        it {
          is_expected.to contain_file('/etc/pihole').with(
            ensure: 'directory',
            owner: 'pihole',
            group: 'pihole',
            mode: '0755'
          )
        }

        it {
          is_expected.to contain_file('/etc/pihole/setupVars.conf').with(
            ensure: 'file',
            owner: 'pihole',
            group: 'pihole',
            mode: '0644'
          )
        }

        it {
          is_expected.to contain_file('/etc/dnsmasq.d/01-pihole.conf').with(
            ensure: 'file',
            owner: 'root',
            group: 'root',
            mode: '0644'
          )
        }

        it {
          is_expected.to contain_file('/etc/pihole/pihole-FTL.conf').with(
            ensure: 'file',
            owner: 'pihole',
            group: 'pihole',
            mode: '0644'
          )
        }

        it { is_expected.to contain_service('pihole-FTL').with_ensure('running') }
        it { is_expected.to contain_service('pihole-FTL').with_enable(true) }

        it { is_expected.to contain_exec('pihole-reload-dns').with_refreshonly(true) }

        context 'with default install_pihole (true)' do
          it {
            is_expected.to contain_exec('install-pihole').with(
              command: %r{curl -sSL https://install.pi-hole.net},
              creates: '/usr/local/bin/pihole'
            )
          }

          it {
            is_expected.to contain_exec('set-pihole-password').with(
              command: /pihole -a -p/,
              unless: 'test -f /etc/pihole/.password_set'
            )
          }

          it {
            is_expected.to contain_file('/etc/pihole/.password_set').with(
              ensure: 'file',
              owner: 'pihole',
              group: 'pihole',
              mode: '0640'
            )
          }
        end

        context 'with install_pihole disabled' do
          let(:params) do
            super().merge(
              install_pihole: false
            )
          end

          it { is_expected.not_to contain_exec('install-pihole') }
          it { is_expected.not_to contain_exec('set-pihole-password') }
        end

        context 'with local_dns_records configured' do
          let(:params) do
            super().merge(
              local_dns_records: {
                'emby.home.server' => '192.168.1.10',
                'emby.travel.server' => '10.10.10.10'
              }
            )
          end

          it {
            is_expected.to contain_file('/etc/pihole/custom.list').with(
              ensure: 'file',
              owner: 'pihole',
              group: 'pihole',
              mode: '0644'
            )
          }
        end

        context 'with upstream_dns_servers configured' do
          let(:params) do
            super().merge(
              upstream_dns_servers: ['127.0.0.1#5353']
            )
          end

          it { is_expected.to compile.with_all_deps }
        end
      end
    end
  end
end
