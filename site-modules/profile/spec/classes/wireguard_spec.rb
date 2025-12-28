# frozen_string_literal: true

require 'spec_helper'

describe 'profile::wireguard' do
  on_supported_os.each do |os, os_facts|
    context "when on #{os}" do
      let(:facts) { os_facts }

      context 'with default parameters' do
        it { is_expected.to compile.with_all_deps }
        it { is_expected.not_to contain_package('wireguard') }
      end

      context 'with manage_wireguard enabled' do
        let(:params) do
          {
            manage_wireguard: true,
            server_private_key: 'test_private_key_here',
            vpn_network: '10.10.10.0/24',
            vpn_server_ip: '10.10.10.1',
            external_interface: 'eth0'
          }
        end

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_package('wireguard') }

        it {
          is_expected.to contain_file('/etc/wireguard').with(
            ensure: 'directory',
            owner: 'root',
            group: 'root',
            mode: '0700'
          )
        }

        it {
          is_expected.to contain_file('/etc/wireguard/clients').with(
            ensure: 'directory',
            owner: 'root',
            group: 'root',
            mode: '0700'
          )
        }

        it {
          is_expected.to contain_file('/etc/wireguard/clientconfs').with(
            ensure: 'directory',
            owner: 'root',
            group: 'root',
            mode: '0700'
          )
        }

        it {
          is_expected.to contain_file('/etc/wireguard/wg0.conf').with(
            ensure: 'file',
            owner: 'root',
            group: 'root',
            mode: '0600'
          )
        }

        it { is_expected.to contain_service('wg-quick@wg0').with_ensure('running') }
        it { is_expected.to contain_service('wg-quick@wg0').with_enable(true) }

        it {
          is_expected.to contain_sysctl('net.ipv4.ip_forward').with(
            ensure: 'present',
            value: '1'
          )
        }

        context 'with manage_ufw enabled' do
          it {
            is_expected.to contain_class('ufw').with(
              default_input_policy: 'deny',
              default_output_policy: 'allow',
              default_forward_policy: 'deny',
              default_application_policy: 'skip'
            )
          }

          it { is_expected.to contain_ufw_rule('allow wireguard port 51820') }
          it { is_expected.to contain_ufw_rule('allow DNS from VPN network') }
          it { is_expected.to contain_ufw_rule('allow HTTP from VPN network') }
          it { is_expected.to contain_ufw_rule('allow HTTPS from VPN network') }
          it { is_expected.to contain_ufw_route('allow VPN traffic from wg0 to eth0') }
          it { is_expected.to contain_ufw_route('allow VPN-to-VPN traffic on wg0') }
        end

        context 'with peers configured' do
          let(:params) do
            super().merge(
              peers: {
                'homeserver' => {
                  'public_key' => 'homeserver_public_key',
                  'preshared_key' => 'homeserver_psk',
                  'allowed_ips' => '10.10.10.10/32'
                }
              }
            )
          end

          it {
            is_expected.to contain_file('/etc/wireguard/clients/homeserver.psk').with(
              ensure: 'file',
              owner: 'root',
              group: 'root',
              mode: '0600'
            )
          }
        end
      end

      context 'without server_private_key' do
        let(:params) do
          {
            manage_wireguard: true
          }
        end

        it { is_expected.to compile.and_raise_error(/server_private_key is required/) }
      end
    end
  end
end
