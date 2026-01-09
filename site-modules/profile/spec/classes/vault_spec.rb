# frozen_string_literal: true

require 'spec_helper'

describe 'profile::vault' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      context 'with default parameters (manage_vault => false)' do
        it { is_expected.to compile.with_all_deps }
        it { is_expected.not_to contain_file('/etc/vault.d') }
        it { is_expected.not_to contain_file('/etc/vault.d/agent.hcl') }
      end

      context 'with manage_vault => true and approle auth' do
        let(:params) do
          {
            manage_vault: true,
            vault_addr: 'https://vault.example.com:8200',
            vault_auth_method: 'approle',
            vault_role: 'puppet-agent'
          }
        end

        it { is_expected.to compile.with_all_deps }

        it {
          is_expected.to contain_file('/etc/vault.d').with(
            ensure: 'directory',
            owner: 'root',
            group: 'root',
            mode: '0755'
          )
        }

        it {
          is_expected.to contain_file('/etc/vault.d/agent.hcl').with(
            ensure: 'file',
            owner: 'root',
            group: 'root',
            mode: '0640'
          ).that_requires('File[/etc/vault.d]')
        }

        it {
          is_expected.to contain_file('/etc/vault.d/agent.hcl')
            .with_content(%r{address = "https://vault\.example\.com:8200"})
        }

        it {
          is_expected.to contain_file('/etc/vault.d/agent.hcl')
            .with_content(/method "approle"/)
        }

        it {
          is_expected.to contain_systemd__unit_file('vault-agent.service')
            .with(enable: true, active: true)
            .that_requires('File[/etc/vault.d/agent.hcl]')
        }

        it {
          is_expected.to contain_file('/etc/facter/facts.d/vault.yaml')
            .with_content(/vault_available: true/)
        }
      end

      context 'with cert auth method' do
        let(:facts) do
          os_facts.merge(
            trusted: {
              'certname' => 'test.example.com'
            }
          )
        end

        let(:params) do
          {
            manage_vault: true,
            vault_addr: 'https://vault.example.com:8200',
            vault_auth_method: 'cert',
            vault_role: 'puppet-cert'
          }
        end

        it { is_expected.to compile.with_all_deps }

        it {
          is_expected.to contain_file('/etc/vault.d/agent.hcl')
            .with_content(/method "cert"/)
        }
      end

      context 'with vault namespace (Enterprise)' do
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
