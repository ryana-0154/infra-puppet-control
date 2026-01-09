# frozen_string_literal: true

require 'spec_helper'

describe 'profile::vault_agent' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }
      let(:node) { 'test.example.com' }

      context 'with default parameters' do
        it { is_expected.to compile.with_all_deps }
        it { is_expected.not_to contain_file('/etc/vault.d') }
      end

      context 'with manage_vault enabled' do
        let(:params) do
          {
            manage_vault: true,
            vault_addr: 'https://vault.example.com:8200',
            vault_role: 'puppet-nodes'
          }
        end

        it { is_expected.to compile.with_all_deps }

        it {
          is_expected.to contain_file('/etc/vault.d')
            .with_ensure('directory')
            .with_owner('root')
            .with_group('root')
            .with_mode('0755')
        }

        it {
          is_expected.to contain_file('/etc/vault.d/agent.hcl')
            .with_ensure('file')
            .with_owner('root')
            .with_mode('0640')
            .with_content(/vault \{/)
            .with_content(%r{address = "https://vault\.example\.com:8200"})
        }

        it {
          is_expected.to contain_systemd__unit_file('vault-agent.service')
            .with_enable(true)
            .with_active(true)
        }

        it {
          is_expected.to contain_file('/etc/facter/facts.d/vault.yaml')
            .with_ensure('file')
            .with_content(/vault_available: true/)
        }
      end

      context 'with cert auth method' do
        let(:params) do
          {
            manage_vault: true,
            vault_addr: 'https://vault.example.com:8200',
            vault_auth_method: 'cert'
          }
        end

        it { is_expected.to compile.with_all_deps }

        it {
          is_expected.to contain_file('/etc/vault.d/agent.hcl')
            .with_content(/method = "cert"/)
        }
      end

      context 'with vault namespace' do
        let(:params) do
          {
            manage_vault: true,
            vault_addr: 'https://vault.example.com:8200',
            vault_namespace: 'admin/infrastructure'
          }
        end

        it { is_expected.to compile.with_all_deps }

        it {
          is_expected.to contain_file('/etc/vault.d/agent.hcl')
            .with_content(%r{namespace = "admin/infrastructure"})
        }
      end
    end
  end
end
