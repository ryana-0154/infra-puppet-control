# frozen_string_literal: true

require 'spec_helper'

describe 'profile::vault' do
  on_supported_os.each do |os, os_facts|
    context "when running on #{os}" do
      let(:facts) { os_facts }

      context 'with default parameters (disabled)' do
        it { is_expected.to compile.with_all_deps }

        it 'does not create any Vault resources' do
          is_expected.not_to contain_file('/opt/vault')
          is_expected.not_to contain_exec('start-vault')
          is_expected.not_to contain_exec('restart-vault')
        end
      end

      context 'with manage_vault enabled (TLS disabled for testing)' do
        let(:params) do
          {
            manage_vault: true,
            tls_enabled: false
          }
        end

        it { is_expected.to compile.with_all_deps }

        it 'creates vault base directory' do
          is_expected.to contain_file('/opt/vault').with(ensure: 'directory', mode: '0755')
        end

        it 'creates vault subdirectories', :aggregate_failures do
          %w[data config logs certs plugins].each do |subdir|
            is_expected.to contain_file("/opt/vault/#{subdir}").with(ensure: 'directory')
          end
        end

        it 'creates Vault configuration file' do
          is_expected.to contain_file('/opt/vault/config/vault.hcl').with(
            ensure: 'file',
            mode: '0644',
            owner: 'root',
            group: 'root'
          )
        end

        it 'creates Docker Compose file' do
          is_expected.to contain_file('/opt/vault/docker-compose.yaml').with(
            ensure: 'file',
            mode: '0644',
            owner: 'root',
            group: 'root'
          )
        end

        it 'creates environment file with restricted permissions' do
          is_expected.to contain_file('/opt/vault/.env').with(
            ensure: 'file',
            mode: '0600',
            owner: 'root',
            group: 'root'
          )
        end

        it 'starts docker-compose stack' do
          is_expected.to contain_exec('start-vault').with(
            command: 'docker compose up -d',
            cwd: '/opt/vault'
          )
        end

        it 'restarts containers on config changes' do
          is_expected.to contain_exec('restart-vault').with(
            command: 'docker compose up -d --force-recreate',
            cwd: '/opt/vault',
            refreshonly: true
          )
        end

        it 'installs docker-compose-plugin' do
          is_expected.to contain_package('docker-compose-plugin')
        end

        it 'creates helper scripts' do
          is_expected.to contain_file('/opt/vault/vault-cli.sh').with(
            ensure: 'file',
            mode: '0755'
          )
          is_expected.to contain_file('/opt/vault/foreman-setup.sh').with(
            ensure: 'file',
            mode: '0755'
          )
        end

        it 'configures file storage backend by default' do
          is_expected.to contain_file('/opt/vault/config/vault.hcl').with_content(
            /storage "file"/
          )
        end

        it 'disables TLS in config' do
          is_expected.to contain_file('/opt/vault/config/vault.hcl').with_content(
            /tls_disable\s+=\s+true/
          )
        end

        it 'enables UI by default' do
          is_expected.to contain_file('/opt/vault/config/vault.hcl').with_content(
            /ui = true/
          )
        end
      end

      context 'with TLS enabled' do
        let(:params) do
          {
            manage_vault: true,
            tls_enabled: true,
            tls_cert_source: '/etc/letsencrypt/live/vault.example.com/fullchain.pem',
            tls_key_source: '/etc/letsencrypt/live/vault.example.com/privkey.pem'
          }
        end

        it { is_expected.to compile.with_all_deps }

        it 'copies TLS certificate' do
          is_expected.to contain_file('/opt/vault/certs/cert.pem').with(
            ensure: 'file',
            source: '/etc/letsencrypt/live/vault.example.com/fullchain.pem',
            mode: '0644'
          )
        end

        it 'copies TLS key with restricted permissions' do
          is_expected.to contain_file('/opt/vault/certs/key.pem').with(
            ensure: 'file',
            source: '/etc/letsencrypt/live/vault.example.com/privkey.pem',
            mode: '0600'
          )
        end

        it 'configures TLS in vault.hcl' do
          is_expected.to contain_file('/opt/vault/config/vault.hcl').with_content(
            %r{tls_cert_file\s+=\s+"/vault/certs/cert\.pem"}
          )
          is_expected.to contain_file('/opt/vault/config/vault.hcl').with_content(
            %r{tls_key_file\s+=\s+"/vault/certs/key\.pem"}
          )
          is_expected.to contain_file('/opt/vault/config/vault.hcl').with_content(
            /tls_disable\s+=\s+false/
          )
        end
      end

      context 'with TLS enabled but missing certificate source' do
        let(:params) do
          {
            manage_vault: true,
            tls_enabled: true,
            tls_key_source: '/etc/letsencrypt/live/vault.example.com/privkey.pem'
            # tls_cert_source is missing
          }
        end

        it { is_expected.to compile.and_raise_error(/tls_cert_source and tls_key_source are required when tls_enabled is true/) }
      end

      context 'with custom directory' do
        let(:params) do
          {
            manage_vault: true,
            vault_dir: '/custom/vault/path',
            tls_enabled: false
          }
        end

        it { is_expected.to compile.with_all_deps }

        it 'uses custom directory' do
          is_expected.to contain_file('/custom/vault/path').with(
            ensure: 'directory'
          )
          is_expected.to contain_file('/custom/vault/path/docker-compose.yaml')
          is_expected.to contain_file('/custom/vault/path/.env')
          is_expected.to contain_file('/custom/vault/path/config/vault.hcl')
        end

        it 'uses custom directory in exec commands' do
          is_expected.to contain_exec('start-vault').with(
            cwd: '/custom/vault/path'
          )
          is_expected.to contain_exec('restart-vault').with(
            cwd: '/custom/vault/path'
          )
        end
      end

      context 'with custom ports' do
        let(:params) do
          {
            manage_vault: true,
            api_port: 8300,
            cluster_port: 8301,
            tls_enabled: false
          }
        end

        it { is_expected.to compile.with_all_deps }

        it 'configures custom ports in compose file' do
          is_expected.to contain_file('/opt/vault/docker-compose.yaml').with_content(
            /"8300:8200"/
          )
          is_expected.to contain_file('/opt/vault/docker-compose.yaml').with_content(
            /"8301:8201"/
          )
        end
      end

      context 'with Raft storage backend' do
        let(:params) do
          {
            manage_vault: true,
            storage_backend: 'raft',
            raft_node_id: 'vault-1',
            raft_cluster_members: [
              'https://vault-2.example.com:8201',
              'https://vault-3.example.com:8201'
            ],
            tls_enabled: false
          }
        end

        it { is_expected.to compile.with_all_deps }

        it 'creates raft directory' do
          is_expected.to contain_file('/opt/vault/raft').with(
            ensure: 'directory'
          )
        end

        it 'configures Raft storage in vault.hcl' do
          is_expected.to contain_file('/opt/vault/config/vault.hcl').with_content(
            /storage "raft"/
          )
          is_expected.to contain_file('/opt/vault/config/vault.hcl').with_content(
            /node_id = "vault-1"/
          )
          is_expected.to contain_file('/opt/vault/config/vault.hcl').with_content(
            %r{leader_api_addr = "https://vault-2\.example\.com:8201"}
          )
          is_expected.to contain_file('/opt/vault/config/vault.hcl').with_content(
            %r{leader_api_addr = "https://vault-3\.example\.com:8201"}
          )
        end

        it 'mounts raft directory in compose file' do
          is_expected.to contain_file('/opt/vault/docker-compose.yaml').with_content(
            %r{/opt/vault/raft:/vault/raft}
          )
        end
      end

      context 'with Raft storage but missing node_id' do
        let(:params) do
          {
            manage_vault: true,
            storage_backend: 'raft',
            tls_enabled: false
            # raft_node_id is missing
          }
        end

        it { is_expected.to compile.and_raise_error(/raft_node_id is required when storage_backend is raft/) }
      end

      context 'with custom logging' do
        let(:params) do
          {
            manage_vault: true,
            log_level: 'debug',
            tls_enabled: false
          }
        end

        it { is_expected.to compile.with_all_deps }

        it 'configures logging in vault.hcl' do
          is_expected.to contain_file('/opt/vault/config/vault.hcl').with_content(
            /log_level = "debug"/
          )
        end

        it 'configures logging in environment file' do
          is_expected.to contain_file('/opt/vault/.env').with_content(
            /VAULT_LOG_LEVEL=debug/
          )
        end
      end

      context 'with telemetry enabled' do
        let(:params) do
          {
            manage_vault: true,
            telemetry_enabled: true,
            tls_enabled: false
          }
        end

        it { is_expected.to compile.with_all_deps }

        it 'configures telemetry in vault.hcl' do
          is_expected.to contain_file('/opt/vault/config/vault.hcl').with_content(
            /telemetry \{/
          )
          is_expected.to contain_file('/opt/vault/config/vault.hcl').with_content(
            /prometheus_retention_time = "30s"/
          )
        end
      end

      context 'with custom lease TTLs' do
        let(:params) do
          {
            manage_vault: true,
            max_lease_ttl: '720h',
            default_lease_ttl: '24h',
            tls_enabled: false
          }
        end

        it { is_expected.to compile.with_all_deps }

        it 'configures lease TTLs in vault.hcl' do
          is_expected.to contain_file('/opt/vault/config/vault.hcl').with_content(
            /max_lease_ttl = "720h"/
          )
          is_expected.to contain_file('/opt/vault/config/vault.hcl').with_content(
            /default_lease_ttl = "24h"/
          )
        end
      end

      context 'with UI disabled' do
        let(:params) do
          {
            manage_vault: true,
            ui_enabled: false,
            tls_enabled: false
          }
        end

        it { is_expected.to compile.with_all_deps }

        it 'disables UI in vault.hcl' do
          is_expected.to contain_file('/opt/vault/config/vault.hcl').with_content(
            /ui = false/
          )
        end
      end

      context 'with custom Docker image' do
        let(:params) do
          {
            manage_vault: true,
            vault_image: 'hashicorp/vault:1.17.0',
            tls_enabled: false
          }
        end

        it { is_expected.to compile.with_all_deps }

        it 'uses custom image in compose file' do
          is_expected.to contain_file('/opt/vault/docker-compose.yaml').with_content(
            %r{image: hashicorp/vault:1\.17\.0}
          )
        end
      end

      context 'with custom API address' do
        let(:params) do
          {
            manage_vault: true,
            api_addr: 'https://vault.example.com:8200',
            cluster_addr: 'https://vault.example.com:8201',
            tls_enabled: false
          }
        end

        it { is_expected.to compile.with_all_deps }

        it 'configures custom addresses in vault.hcl' do
          is_expected.to contain_file('/opt/vault/config/vault.hcl').with_content(
            %r{api_addr = "https://vault\.example\.com:8200"}
          )
          is_expected.to contain_file('/opt/vault/config/vault.hcl').with_content(
            %r{cluster_addr = "https://vault\.example\.com:8201"}
          )
        end

        it 'configures custom address in environment file' do
          is_expected.to contain_file('/opt/vault/.env').with_content(
            %r{VAULT_ADDR=https://vault\.example\.com:8200}
          )
        end
      end
    end
  end
end
