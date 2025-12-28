# frozen_string_literal: true

require 'spec_helper'

describe 'profile::ssh_hardening' do
  on_supported_os.each do |os, os_facts|
    context "when on #{os}" do
      let(:facts) { os_facts }

      context 'with default parameters' do
        it { is_expected.to compile.with_all_deps }
        it { is_expected.not_to contain_class('ssh') }
      end

      context 'with manage_ssh enabled' do
        let(:params) do
          {
            manage_ssh: true
          }
        end

        it { is_expected.to compile.with_all_deps }

        it {
          is_expected.to contain_class('ssh').with(
            storeconfigs_enabled: false
          )
        }

        it 'configures SSH with secure defaults' do
          is_expected.to contain_class('ssh').with(
            server_options: hash_including(
              'Port' => 22,
              'Protocol' => 2,
              'PermitRootLogin' => 'prohibit-password',
              'PubkeyAuthentication' => 'yes',
              'PasswordAuthentication' => 'no',
              'ChallengeResponseAuthentication' => 'no',
              'X11Forwarding' => 'no'
            )
          )
        end
      end

      context 'with custom SSH port' do
        let(:params) do
          {
            manage_ssh: true,
            ssh_port: 2222
          }
        end

        it { is_expected.to compile.with_all_deps }

        it {
          is_expected.to contain_class('ssh').with(
            server_options: hash_including(
              'Port' => 2222
            )
          )
        }
      end

      context 'with password authentication enabled' do
        let(:params) do
          {
            manage_ssh: true,
            password_authentication: 'yes'
          }
        end

        it { is_expected.to compile.with_all_deps }

        it {
          is_expected.to contain_class('ssh').with(
            server_options: hash_including(
              'PasswordAuthentication' => 'yes'
            )
          )
        }
      end

      context 'with root login fully disabled' do
        let(:params) do
          {
            manage_ssh: true,
            permit_root_login: 'no'
          }
        end

        it { is_expected.to compile.with_all_deps }

        it {
          is_expected.to contain_class('ssh').with(
            server_options: hash_including(
              'PermitRootLogin' => 'no'
            )
          )
        }
      end

      context 'with custom keepalive settings' do
        let(:params) do
          {
            manage_ssh: true,
            client_alive_interval: 600,
            client_alive_count_max: 5
          }
        end

        it { is_expected.to compile.with_all_deps }

        it {
          is_expected.to contain_class('ssh').with(
            server_options: hash_including(
              'ClientAliveInterval' => 600,
              'ClientAliveCountMax' => 5
            )
          )
        }
      end

      context 'with custom ciphers' do
        let(:params) do
          {
            manage_ssh: true,
            ciphers: ['chacha20-poly1305@openssh.com', 'aes256-gcm@openssh.com']
          }
        end

        it { is_expected.to compile.with_all_deps }

        it {
          is_expected.to contain_class('ssh').with(
            server_options: hash_including(
              'Ciphers' => 'chacha20-poly1305@openssh.com,aes256-gcm@openssh.com'
            )
          )
        }
      end

      context 'with custom MACs' do
        let(:params) do
          {
            manage_ssh: true,
            macs: ['hmac-sha2-512-etm@openssh.com', 'hmac-sha2-256-etm@openssh.com']
          }
        end

        it { is_expected.to compile.with_all_deps }

        it {
          is_expected.to contain_class('ssh').with(
            server_options: hash_including(
              'MACs' => 'hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com'
            )
          )
        }
      end

      context 'with custom KEX algorithms' do
        let(:params) do
          {
            manage_ssh: true,
            kex_algorithms: ['curve25519-sha256', 'curve25519-sha256@libssh.org']
          }
        end

        it { is_expected.to compile.with_all_deps }

        it {
          is_expected.to contain_class('ssh').with(
            server_options: hash_including(
              'KexAlgorithms' => 'curve25519-sha256,curve25519-sha256@libssh.org'
            )
          )
        }
      end
    end
  end
end
