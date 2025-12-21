# frozen_string_literal: true

require 'spec_helper'

describe 'profile::firewall' do
  on_supported_os.each do |os, os_facts|
    context "when running on #{os}" do
      let(:facts) { os_facts }

      context 'with default parameters' do
        it { is_expected.to compile.with_all_deps }

        it 'includes firewall class' do
          is_expected.to contain_class('firewall')
        end

        it 'sets up resource purging' do
          is_expected.to contain_resources('firewall').with_purge(true)
        end

        it 'configures INPUT policy' do
          is_expected.to contain_firewallchain('INPUT:filter:IPv4').with(
            ensure: 'present',
            policy: 'drop'
          )
        end

        it 'configures OUTPUT policy' do
          is_expected.to contain_firewallchain('OUTPUT:filter:IPv4').with(
            ensure: 'present',
            policy: 'accept'
          )
        end

        it 'configures FORWARD policy' do
          is_expected.to contain_firewallchain('FORWARD:filter:IPv4').with(
            ensure: 'present',
            policy: 'drop'
          )
        end

        it 'allows loopback traffic' do
          is_expected.to contain_firewall('001 accept all to lo interface').with(
            proto: 'all',
            iniface: 'lo',
            jump: 'accept'
          )
        end

        it 'rejects local traffic not on loopback' do
          is_expected.to contain_firewall('002 reject local traffic not on loopback interface').with(
            iniface: '! lo',
            proto: 'all',
            destination: '127.0.0.1/8',
            jump: 'reject'
          )
        end

        it 'allows established connections' do
          is_expected.to contain_firewall('003 accept related established rules').with(
            proto: 'all',
            state: %w[RELATED ESTABLISHED],
            jump: 'accept'
          )
        end

        it 'allows SSH access' do
          is_expected.to contain_firewall('010 allow ssh from 0.0.0.0/0').with(
            dport: 22,
            proto: 'tcp',
            source: '0.0.0.0/0',
            jump: 'accept'
          )
        end

        it 'allows ICMP ping' do
          is_expected.to contain_firewall('020 allow icmp').with(
            proto: 'icmp',
            jump: 'accept'
          )
        end

        it 'does not allow monitoring ports globally by default' do
          is_expected.not_to contain_firewall('030 allow monitoring port 9090 from anywhere')
          is_expected.not_to contain_firewall('030 allow monitoring port 9100 from anywhere')
          is_expected.not_to contain_firewall('030 allow monitoring port 9115 from anywhere')
        end

        it 'does not have explicit final drop rule (relies on policy)' do
          is_expected.not_to contain_firewall('999 drop all other input')
        end
      end

      context 'with custom SSH port' do
        let(:params) do
          {
            'ssh_port' => 2222
          }
        end

        it { is_expected.to compile.with_all_deps }

        it 'allows SSH on custom port' do
          is_expected.to contain_firewall('010 allow ssh from 0.0.0.0/0').with(
            dport: 2222,
            proto: 'tcp',
            jump: 'accept'
          )
        end
      end

      context 'with restricted SSH sources' do
        let(:params) do
          {
            'ssh_source' => ['192.168.1.0/24', '10.0.0.0/8']
          }
        end

        it { is_expected.to compile.with_all_deps }

        it 'allows SSH from first specified network' do
          is_expected.to contain_firewall('010 allow ssh from 192.168.1.0/24').with(
            dport: 22,
            proto: 'tcp',
            source: '192.168.1.0/24',
            jump: 'accept'
          )
        end

        it 'allows SSH from second specified network' do
          is_expected.to contain_firewall('010 allow ssh from 10.0.0.0/8').with(
            dport: 22,
            proto: 'tcp',
            source: '10.0.0.0/8',
            jump: 'accept'
          )
        end
      end

      context 'with ping disabled' do
        let(:params) do
          {
            'allow_ping' => false
          }
        end

        it { is_expected.to compile.with_all_deps }

        it 'does not allow ICMP ping' do
          is_expected.not_to contain_firewall('020 allow icmp')
        end
      end

      context 'with custom rules' do
        let(:params) do
          {
            'custom_rules' => {
              'web_http' => {
                'port' => 80,
                'proto' => 'tcp',
                'jump' => 'accept'
              },
              'web_https' => {
                'port' => 443,
                'proto' => 'tcp',
                'jump' => 'accept'
              }
            }
          }
        end

        it { is_expected.to compile.with_all_deps }

        it 'creates custom firewall rules' do
          is_expected.to contain_firewall('100 custom rule web_http').with(
            port: 80,
            proto: 'tcp',
            jump: 'accept'
          )
          is_expected.to contain_firewall('100 custom rule web_https').with(
            port: 443,
            proto: 'tcp',
            jump: 'accept'
          )
        end
      end

      context 'with WireGuard configuration' do
        let(:params) do
          {
            'wireguard_port' => 51_820,
            'wireguard_network' => '10.10.10.0/24',
            'wireguard_interface' => 'wg0'
          }
        end

        it { is_expected.to compile.with_all_deps }

        it 'allows WireGuard UDP traffic' do
          is_expected.to contain_firewall('040 allow wireguard').with(
            dport: 51_820,
            proto: 'udp',
            jump: 'accept'
          )
        end

        it 'allows monitoring from WireGuard network' do
          is_expected.to contain_firewall('050 allow monitoring port 9090 from wireguard').with(
            dport: 9090,
            proto: 'tcp',
            source: '10.10.10.0/24',
            iniface: 'wg0',
            jump: 'accept'
          )
        end

        it 'allows DNS from WireGuard with interface restriction' do
          is_expected.to contain_firewall('051 allow dns from wireguard').with(
            dport: 53,
            proto: 'udp',
            source: '10.10.10.0/24',
            iniface: 'wg0',
            jump: 'accept'
          )
        end

        it 'allows HTTP from WireGuard with interface restriction' do
          is_expected.to contain_firewall('052 allow http from wireguard').with(
            dport: 80,
            proto: 'tcp',
            source: '10.10.10.0/24',
            iniface: 'wg0',
            jump: 'accept'
          )
        end

        it 'allows WireGuard routing when enabled' do
          is_expected.to contain_firewall('060 allow wireguard routing').with(
            chain: 'FORWARD',
            iniface: 'wg0',
            outiface: 'wg0',
            jump: 'accept'
          )
        end
      end

      context 'with custom firewall rules' do
        let(:params) do
          {
            'custom_rules' => {
              'web_server' => {
                'port' => 8080,
                'proto' => 'tcp',
                'jump' => 'accept'
              },
              'api_service' => {
                'dport' => 9000,
                'proto' => 'tcp',
                'source' => '192.168.1.0/24'
              }
            }
          }
        end

        it { is_expected.to compile.with_all_deps }

        it 'creates first custom rule with port mapping' do
          is_expected.to contain_firewall('100 custom rule web_server').with(
            dport: 8080, # port mapped to dport
            proto: 'tcp',
            jump: 'accept'
          )
        end

        it 'creates second custom rule with unique priority' do
          is_expected.to contain_firewall('101 custom rule api_service').with(
            dport: 9000,
            proto: 'tcp',
            source: '192.168.1.0/24',
            jump: 'accept' # default
          )
        end
      end

      context 'with firewall disabled' do
        let(:params) do
          {
            'manage_firewall' => false
          }
        end

        it { is_expected.to compile.with_all_deps }

        it 'does not include firewall class' do
          is_expected.not_to contain_class('firewall')
        end

        it 'does not create any firewall rules' do
          is_expected.not_to contain_firewall('001 accept all to lo interface')
          is_expected.not_to contain_firewall('010 allow ssh from 0.0.0.0/0')
        end
      end
    end
  end
end
