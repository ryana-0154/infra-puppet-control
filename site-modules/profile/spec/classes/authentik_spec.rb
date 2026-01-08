# frozen_string_literal: true

require 'spec_helper'

describe 'profile::authentik' do
  on_supported_os.each do |os, os_facts|
    context "when running on #{os}" do
      let(:facts) { os_facts }

      context 'with default parameters (disabled)' do
        it { is_expected.to compile.with_all_deps }

        it 'does not create any Authentik resources' do
          is_expected.not_to contain_file('/opt/authentik')
          is_expected.not_to contain_exec('start-authentik')
          is_expected.not_to contain_exec('restart-authentik')
        end
      end

      context 'with manage_authentik enabled' do
        let(:params) do
          {
            manage_authentik: true,
            secret_key: 'test-secret-key-for-testing-only-do-not-use-in-production',
            postgres_password: 'test-postgres-password'
          }
        end

        it { is_expected.to compile.with_all_deps }

        it 'creates Authentik directory structure' do
          is_expected.to contain_file('/opt/authentik').with(
            ensure: 'directory',
            mode: '0755',
            owner: 'root',
            group: 'root'
          )
          is_expected.to contain_file('/opt/authentik/media').with(
            ensure: 'directory'
          )
          is_expected.to contain_file('/opt/authentik/templates').with(
            ensure: 'directory'
          )
          is_expected.to contain_file('/opt/authentik/certs').with(
            ensure: 'directory'
          )
        end

        it 'creates bundled service directories by default' do
          is_expected.to contain_file('/opt/authentik/database').with(
            ensure: 'directory'
          )
          is_expected.to contain_file('/opt/authentik/redis').with(
            ensure: 'directory'
          )
        end

        it 'creates Docker Compose file' do
          is_expected.to contain_file('/opt/authentik/docker-compose.yaml').with(
            ensure: 'file',
            mode: '0644',
            owner: 'root',
            group: 'root'
          )
        end

        it 'creates environment file with restricted permissions' do
          is_expected.to contain_file('/opt/authentik/.env').with(
            ensure: 'file',
            mode: '0600',
            owner: 'root',
            group: 'root'
          )
        end

        it 'starts docker-compose stack' do
          is_expected.to contain_exec('start-authentik').with(
            command: 'docker compose up -d',
            cwd: '/opt/authentik'
          )
        end

        it 'restarts containers on config changes' do
          is_expected.to contain_exec('restart-authentik').with(
            command: 'docker compose up -d --force-recreate --remove-orphans',
            cwd: '/opt/authentik',
            refreshonly: true
          )
        end

        it 'installs docker-compose-plugin' do
          is_expected.to contain_package('docker-compose-plugin')
        end

        it 'includes PostgreSQL container in compose file' do
          is_expected.to contain_file('/opt/authentik/docker-compose.yaml').with_content(
            %r{image: docker\.io/library/postgres:16-alpine}
          )
          is_expected.to contain_file('/opt/authentik/docker-compose.yaml').with_content(
            /container_name: authentik-postgresql/
          )
        end

        it 'includes Redis container in compose file' do
          is_expected.to contain_file('/opt/authentik/docker-compose.yaml').with_content(
            %r{image: docker\.io/library/redis:alpine}
          )
          is_expected.to contain_file('/opt/authentik/docker-compose.yaml').with_content(
            /container_name: authentik-redis/
          )
        end

        it 'includes Authentik server in compose file' do
          is_expected.to contain_file('/opt/authentik/docker-compose.yaml').with_content(
            /container_name: authentik-server/
          )
        end

        it 'includes Authentik worker in compose file' do
          is_expected.to contain_file('/opt/authentik/docker-compose.yaml').with_content(
            /container_name: authentik-worker/
          )
        end
      end

      context 'with custom directory' do
        let(:params) do
          {
            manage_authentik: true,
            authentik_dir: '/custom/authentik/path',
            secret_key: 'test-secret-key',
            postgres_password: 'test-password'
          }
        end

        it { is_expected.to compile.with_all_deps }

        it 'uses custom directory' do
          is_expected.to contain_file('/custom/authentik/path').with(
            ensure: 'directory'
          )
          is_expected.to contain_file('/custom/authentik/path/docker-compose.yaml')
          is_expected.to contain_file('/custom/authentik/path/.env')
        end

        it 'uses custom directory in exec commands' do
          is_expected.to contain_exec('start-authentik').with(
            cwd: '/custom/authentik/path'
          )
          is_expected.to contain_exec('restart-authentik').with(
            cwd: '/custom/authentik/path'
          )
        end
      end

      context 'with custom ports' do
        let(:params) do
          {
            manage_authentik: true,
            http_port: 8080,
            https_port: 8443,
            secret_key: 'test-secret-key',
            postgres_password: 'test-password'
          }
        end

        it { is_expected.to compile.with_all_deps }

        it 'configures custom ports in compose file' do
          is_expected.to contain_file('/opt/authentik/docker-compose.yaml').with_content(
            /"8080:9000"/
          )
          is_expected.to contain_file('/opt/authentik/docker-compose.yaml').with_content(
            /"8443:9443"/
          )
        end
      end

      context 'with external PostgreSQL' do
        let(:params) do
          {
            manage_authentik: true,
            enable_bundled_postgresql: false,
            postgres_host: 'db.example.com',
            postgres_port: 5433,
            postgres_db: 'myauthentik',
            postgres_user: 'myuser',
            secret_key: 'test-secret-key',
            postgres_password: 'test-password'
          }
        end

        it { is_expected.to compile.with_all_deps }

        it 'does not create database directory' do
          is_expected.not_to contain_file('/opt/authentik/database')
        end

        it 'does not include PostgreSQL container in compose file' do
          is_expected.to contain_file('/opt/authentik/docker-compose.yaml').without_content(
            /container_name: authentik-postgresql/
          )
        end

        it 'configures external PostgreSQL in environment' do
          is_expected.to contain_file('/opt/authentik/.env').with_content(
            /POSTGRES_HOST=db\.example\.com/
          )
          is_expected.to contain_file('/opt/authentik/.env').with_content(
            /POSTGRES_PORT=5433/
          )
          is_expected.to contain_file('/opt/authentik/.env').with_content(
            /POSTGRES_DB=myauthentik/
          )
          is_expected.to contain_file('/opt/authentik/.env').with_content(
            /POSTGRES_USER=myuser/
          )
        end
      end

      context 'with external Redis' do
        let(:params) do
          {
            manage_authentik: true,
            enable_bundled_redis: false,
            redis_host: 'redis.example.com',
            redis_port: 6380,
            secret_key: 'test-secret-key',
            postgres_password: 'test-password'
          }
        end

        it { is_expected.to compile.with_all_deps }

        it 'does not create redis directory' do
          is_expected.not_to contain_file('/opt/authentik/redis')
        end

        it 'does not include Redis container in compose file' do
          is_expected.to contain_file('/opt/authentik/docker-compose.yaml').without_content(
            /container_name: authentik-redis/
          )
        end

        it 'configures external Redis in environment' do
          is_expected.to contain_file('/opt/authentik/.env').with_content(
            /REDIS_HOST=redis\.example\.com/
          )
          is_expected.to contain_file('/opt/authentik/.env').with_content(
            /REDIS_PORT=6380/
          )
        end
      end

      context 'with email configuration' do
        let(:params) do
          {
            manage_authentik: true,
            email_host: 'smtp.example.com',
            email_port: 465,
            email_username: 'user@example.com',
            email_password: 'smtp-password',
            email_from: 'auth@example.com',
            email_use_tls: false,
            email_use_ssl: true,
            secret_key: 'test-secret-key',
            postgres_password: 'test-password'
          }
        end

        it { is_expected.to compile.with_all_deps }

        it 'configures email host and port' do
          is_expected.to contain_file('/opt/authentik/.env').with_content(
            /AUTHENTIK_EMAIL__HOST=smtp\.example\.com/
          )
          is_expected.to contain_file('/opt/authentik/.env').with_content(
            /AUTHENTIK_EMAIL__PORT=465/
          )
        end

        it 'configures email credentials' do
          is_expected.to contain_file('/opt/authentik/.env').with_content(
            /AUTHENTIK_EMAIL__USERNAME=user@example\.com/
          )
          is_expected.to contain_file('/opt/authentik/.env').with_content(
            /AUTHENTIK_EMAIL__PASSWORD=smtp-password/
          )
          is_expected.to contain_file('/opt/authentik/.env').with_content(
            /AUTHENTIK_EMAIL__FROM=auth@example\.com/
          )
        end

        it 'configures email TLS/SSL settings' do
          is_expected.to contain_file('/opt/authentik/.env').with_content(
            /AUTHENTIK_EMAIL__USE_TLS=false/
          )
          is_expected.to contain_file('/opt/authentik/.env').with_content(
            /AUTHENTIK_EMAIL__USE_SSL=true/
          )
        end
      end

      context 'with GeoIP enabled' do
        let(:params) do
          {
            manage_authentik: true,
            geoip_enabled: true,
            geoip_account_id: '123456',
            geoip_license_key: 'test-license-key',
            secret_key: 'test-secret-key',
            postgres_password: 'test-password'
          }
        end

        it { is_expected.to compile.with_all_deps }

        it 'creates GeoIP directory' do
          is_expected.to contain_file('/opt/authentik/geoip').with(
            ensure: 'directory'
          )
        end

        it 'includes GeoIP container in compose file' do
          is_expected.to contain_file('/opt/authentik/docker-compose.yaml').with_content(
            /container_name: authentik-geoipupdate/
          )
        end

        it 'configures GeoIP in environment file' do
          is_expected.to contain_file('/opt/authentik/.env').with_content(
            /GEOIPUPDATE_ACCOUNT_ID=123456/
          )
          is_expected.to contain_file('/opt/authentik/.env').with_content(
            /GEOIPUPDATE_LICENSE_KEY=test-license-key/
          )
        end
      end

      context 'with GeoIP enabled but missing credentials' do
        let(:params) do
          {
            manage_authentik: true,
            geoip_enabled: true,
            geoip_account_id: '123456',
            # geoip_license_key is missing
            secret_key: 'test-secret-key',
            postgres_password: 'test-password'
          }
        end

        it { is_expected.to compile.and_raise_error(/geoip_account_id and geoip_license_key are required when geoip_enabled is true/) }
      end

      context 'with custom logging' do
        let(:params) do
          {
            manage_authentik: true,
            log_level: 'debug',
            error_reporting_enabled: true,
            secret_key: 'test-secret-key',
            postgres_password: 'test-password'
          }
        end

        it { is_expected.to compile.with_all_deps }

        it 'configures logging in environment file' do
          is_expected.to contain_file('/opt/authentik/.env').with_content(
            /AUTHENTIK_LOG_LEVEL=debug/
          )
          is_expected.to contain_file('/opt/authentik/.env').with_content(
            /AUTHENTIK_ERROR_REPORTING__ENABLED=true/
          )
        end
      end

      context 'with custom Docker images' do
        let(:params) do
          {
            manage_authentik: true,
            authentik_image: 'ghcr.io/goauthentik/server:2024.10',
            postgres_image: 'postgres:15-alpine',
            redis_image: 'redis:7-alpine',
            secret_key: 'test-secret-key',
            postgres_password: 'test-password'
          }
        end

        it { is_expected.to compile.with_all_deps }

        it 'uses custom images in compose file' do
          is_expected.to contain_file('/opt/authentik/docker-compose.yaml').with_content(
            %r{image: ghcr\.io/goauthentik/server:2024\.10}
          )
          is_expected.to contain_file('/opt/authentik/docker-compose.yaml').with_content(
            /image: postgres:15-alpine/
          )
          is_expected.to contain_file('/opt/authentik/docker-compose.yaml').with_content(
            /image: redis:7-alpine/
          )
        end
      end

      context 'without required secret_key' do
        let(:params) do
          {
            manage_authentik: true,
            postgres_password: 'test-password'
            # secret_key is missing
          }
        end

        it { is_expected.to compile.and_raise_error(/secret_key is required when manage_authentik is true/) }
      end

      context 'without required postgres_password' do
        let(:params) do
          {
            manage_authentik: true,
            secret_key: 'test-secret-key'
            # postgres_password is missing
          }
        end

        it { is_expected.to compile.and_raise_error(/postgres_password is required when manage_authentik is true/) }
      end

      context 'with Sensitive type parameters' do
        let(:params) do
          {
            manage_authentik: true,
            secret_key: sensitive('sensitive-secret-key'),
            postgres_password: sensitive('sensitive-postgres-password')
          }
        end

        it { is_expected.to compile.with_all_deps }

        it 'creates environment file' do
          is_expected.to contain_file('/opt/authentik/.env').with(
            ensure: 'file',
            mode: '0600'
          )
        end
      end
    end
  end
end
