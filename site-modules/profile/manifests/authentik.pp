# @summary Manages Authentik identity provider
#
# This profile deploys Authentik, an open-source identity provider that supports
# OAuth2/OIDC, SAML, SCIM, LDAP, and more. It runs as a Docker Compose stack
# with PostgreSQL and Redis backends.
#
# @note Requirements
#   - Docker must be installed and running
#   - This profile will ensure docker-compose-plugin (v2) is installed
#
# @param manage_authentik
#   Whether to manage the Authentik deployment
# @param authentik_dir
#   Base directory for Authentik configuration and data
# @param authentik_image
#   Docker image for Authentik server and worker
# @param http_port
#   Port for HTTP interface (default: 9000)
# @param https_port
#   Port for HTTPS interface (default: 9443)
# @param secret_key
#   Secret key for cookie signing and session management (REQUIRED, should be encrypted with eyaml)
#   Generate with: openssl rand -base64 60
# @param postgres_password
#   Password for PostgreSQL database (REQUIRED, should be encrypted with eyaml)
# @param postgres_host
#   PostgreSQL hostname (default: uses bundled container)
# @param postgres_port
#   PostgreSQL port (default: 5432)
# @param postgres_db
#   PostgreSQL database name
# @param postgres_user
#   PostgreSQL username
# @param redis_host
#   Redis hostname (default: uses bundled container)
# @param redis_port
#   Redis port (default: 6379)
# @param log_level
#   Logging level (debug, info, warning, error)
# @param error_reporting_enabled
#   Whether to enable error reporting to Authentik
# @param email_host
#   SMTP server hostname (optional)
# @param email_port
#   SMTP server port (default: 587)
# @param email_username
#   SMTP username (optional)
# @param email_password
#   SMTP password (optional, should be encrypted with eyaml)
# @param email_from
#   Email from address (default: authentik@localhost)
# @param email_use_tls
#   Whether to use TLS for SMTP (default: true)
# @param email_use_ssl
#   Whether to use SSL for SMTP (default: false)
# @param enable_bundled_postgresql
#   Whether to deploy PostgreSQL container with Authentik (default: true)
# @param enable_bundled_redis
#   Whether to deploy Redis container with Authentik (default: true)
# @param postgres_image
#   Docker image for PostgreSQL (if bundled)
# @param redis_image
#   Docker image for Redis (if bundled)
# @param geoip_enabled
#   Whether to enable GeoIP for location-based policies
# @param geoip_account_id
#   MaxMind account ID for GeoIP (required if geoip_enabled is true)
# @param geoip_license_key
#   MaxMind license key for GeoIP (required if geoip_enabled is true)
#
# @example Basic usage via Hiera
#   profile::authentik::manage_authentik: true
#   profile::authentik::secret_key: 'ENC[PKCS7,...]'
#   profile::authentik::postgres_password: 'ENC[PKCS7,...]'
#
# @example With external PostgreSQL
#   profile::authentik::manage_authentik: true
#   profile::authentik::enable_bundled_postgresql: false
#   profile::authentik::postgres_host: 'db.example.com'
#   profile::authentik::postgres_password: 'ENC[PKCS7,...]'
#   profile::authentik::secret_key: 'ENC[PKCS7,...]'
#
class profile::authentik (
  Boolean              $manage_authentik           = false,
  Stdlib::Absolutepath $authentik_dir              = '/opt/authentik',
  String[1]            $authentik_image            = 'ghcr.io/goauthentik/server:2024.12',

  # Network configuration
  Integer[1,65535]     $http_port                  = 9000,
  Integer[1,65535]     $https_port                 = 9443,

  # Required secrets (must be set via Hiera or Foreman)
  Optional[Variant[String[1], Sensitive[String[1]]]] $secret_key        = undef,
  Optional[Variant[String[1], Sensitive[String[1]]]] $postgres_password = undef,

  # PostgreSQL configuration
  String[1]            $postgres_host              = 'postgresql',
  Integer[1,65535]     $postgres_port              = 5432,
  String[1]            $postgres_db                = 'authentik',
  String[1]            $postgres_user              = 'authentik',

  # Redis configuration
  String[1]            $redis_host                 = 'redis',
  Integer[1,65535]     $redis_port                 = 6379,

  # Logging
  Enum['debug', 'info', 'warning', 'error'] $log_level = 'info',
  Boolean              $error_reporting_enabled    = false,

  # Email configuration (optional)
  Optional[String[1]]  $email_host                 = undef,
  Integer[1,65535]     $email_port                 = 587,
  Optional[String[1]]  $email_username             = undef,
  Optional[Variant[String[1], Sensitive[String[1]]]] $email_password = undef,
  String[1]            $email_from                 = 'authentik@localhost',
  Boolean              $email_use_tls              = true,
  Boolean              $email_use_ssl              = false,

  # Bundled services
  Boolean              $enable_bundled_postgresql  = true,
  Boolean              $enable_bundled_redis       = true,
  String[1]            $postgres_image             = 'docker.io/library/postgres:16-alpine',
  String[1]            $redis_image                = 'docker.io/library/redis:alpine',

  # GeoIP configuration (optional)
  Boolean              $geoip_enabled              = false,
  Optional[String[1]]  $geoip_account_id           = undef,
  Optional[Variant[String[1], Sensitive[String[1]]]] $geoip_license_key = undef,
  String[1]            $geoip_image                = 'ghcr.io/maxmind/geoipupdate:latest',
) {
  # Multi-source parameter resolution (Foreman ENC -> Hiera -> Defaults)
  $_manage_authentik = pick(
    getvar('authentik_manage'),
    lookup('profile::authentik::manage_authentik', Optional[Boolean], 'first', undef),
    $manage_authentik
  )

  # Secret key resolution with Sensitive handling
  $_secret_key_raw = getvar('authentik_secret_key')
  $_secret_key_hiera = lookup('profile::authentik::secret_key', Optional[Variant[String, Sensitive[String]]], 'first', undef)
  $_secret_key_hiera_wrapped = $_secret_key_hiera ? {
    Sensitive => $_secret_key_hiera,
    String    => Sensitive($_secret_key_hiera),
    default   => undef,
  }
  $_secret_key_param = $secret_key ? {
    Sensitive => $secret_key,
    String    => Sensitive($secret_key),
    default   => undef,
  }
  $_secret_key = $_secret_key_raw ? {
    undef   => $_secret_key_hiera_wrapped ? {
      undef   => $_secret_key_param,
      default => $_secret_key_hiera_wrapped,
    },
    default => Sensitive($_secret_key_raw),
  }

  # PostgreSQL password resolution with Sensitive handling
  $_postgres_password_raw = getvar('authentik_postgres_password')
  $_postgres_password_hiera = lookup('profile::authentik::postgres_password', Optional[Variant[String, Sensitive[String]]], 'first', undef)
  $_postgres_password_hiera_wrapped = $_postgres_password_hiera ? {
    Sensitive => $_postgres_password_hiera,
    String    => Sensitive($_postgres_password_hiera),
    default   => undef,
  }
  $_postgres_password_param = $postgres_password ? {
    Sensitive => $postgres_password,
    String    => Sensitive($postgres_password),
    default   => undef,
  }
  $_postgres_password = $_postgres_password_raw ? {
    undef   => $_postgres_password_hiera_wrapped ? {
      undef   => $_postgres_password_param,
      default => $_postgres_password_hiera_wrapped,
    },
    default => Sensitive($_postgres_password_raw),
  }

  # Email password resolution with Sensitive handling
  $_email_password_raw = getvar('authentik_email_password')
  $_email_password_hiera = lookup('profile::authentik::email_password', Optional[Variant[String, Sensitive[String]]], 'first', undef)
  $_email_password_hiera_wrapped = $_email_password_hiera ? {
    Sensitive => $_email_password_hiera,
    String    => Sensitive($_email_password_hiera),
    default   => undef,
  }
  $_email_password_param = $email_password ? {
    Sensitive => $email_password,
    String    => Sensitive($email_password),
    default   => undef,
  }
  $_email_password = $_email_password_raw ? {
    undef   => $_email_password_hiera_wrapped ? {
      undef   => $_email_password_param,
      default => $_email_password_hiera_wrapped,
    },
    default => Sensitive($_email_password_raw),
  }

  # GeoIP license key resolution with Sensitive handling
  $_geoip_license_key_raw = getvar('authentik_geoip_license_key')
  $_geoip_license_key_hiera = lookup('profile::authentik::geoip_license_key', Optional[Variant[String, Sensitive[String]]], 'first', undef)
  $_geoip_license_key_hiera_wrapped = $_geoip_license_key_hiera ? {
    Sensitive => $_geoip_license_key_hiera,
    String    => Sensitive($_geoip_license_key_hiera),
    default   => undef,
  }
  $_geoip_license_key_param = $geoip_license_key ? {
    Sensitive => $geoip_license_key,
    String    => Sensitive($geoip_license_key),
    default   => undef,
  }
  $_geoip_license_key = $_geoip_license_key_raw ? {
    undef   => $_geoip_license_key_hiera_wrapped ? {
      undef   => $_geoip_license_key_param,
      default => $_geoip_license_key_hiera_wrapped,
    },
    default => Sensitive($_geoip_license_key_raw),
  }

  # Validation
  if $_manage_authentik {
    if !$_secret_key {
      fail('profile::authentik: secret_key is required when manage_authentik is true')
    }
    if !$_postgres_password {
      fail('profile::authentik: postgres_password is required when manage_authentik is true')
    }
    if $geoip_enabled and (!$geoip_account_id or !$_geoip_license_key) {
      fail('profile::authentik: geoip_account_id and geoip_license_key are required when geoip_enabled is true')
    }
  }

  if $_manage_authentik {
    # Ensure Docker Compose v2 is installed
    ensure_packages(['docker-compose-plugin'])

    # Create Authentik directory structure
    file { [$authentik_dir, "${authentik_dir}/media", "${authentik_dir}/templates", "${authentik_dir}/certs"]:
      ensure => directory,
      mode   => '0755',
      owner  => 'root',
      group  => 'root',
    }

    # Create data directories for bundled services
    if $enable_bundled_postgresql {
      file { "${authentik_dir}/database":
        ensure => directory,
        mode   => '0755',
        owner  => 'root',
        group  => 'root',
      }
    }

    if $enable_bundled_redis {
      file { "${authentik_dir}/redis":
        ensure => directory,
        mode   => '0755',
        owner  => 'root',
        group  => 'root',
      }
    }

    if $geoip_enabled {
      file { "${authentik_dir}/geoip":
        ensure => directory,
        mode   => '0755',
        owner  => 'root',
        group  => 'root',
      }
    }

    # Docker Compose configuration
    file { "${authentik_dir}/docker-compose.yaml":
      ensure  => file,
      mode    => '0644',
      owner   => 'root',
      group   => 'root',
      content => epp('profile/authentik/docker-compose.yaml.epp', {
          authentik_dir             => $authentik_dir,
          authentik_image           => $authentik_image,
          http_port                 => $http_port,
          https_port                => $https_port,
          postgres_host             => $postgres_host,
          postgres_port             => $postgres_port,
          postgres_db               => $postgres_db,
          postgres_user             => $postgres_user,
          redis_host                => $redis_host,
          redis_port                => $redis_port,
          enable_bundled_postgresql => $enable_bundled_postgresql,
          enable_bundled_redis      => $enable_bundled_redis,
          postgres_image            => $postgres_image,
          redis_image               => $redis_image,
          geoip_enabled             => $geoip_enabled,
          geoip_image               => $geoip_image,
      }),
      require => File[$authentik_dir],
    }

    # Environment file for secrets (mode 0600 for security)
    file { "${authentik_dir}/.env":
      ensure  => file,
      mode    => '0600',
      owner   => 'root',
      group   => 'root',
      content => epp('profile/authentik/.env.epp', {
          secret_key              => $_secret_key,
          postgres_password       => $_postgres_password,
          postgres_host           => $postgres_host,
          postgres_port           => $postgres_port,
          postgres_db             => $postgres_db,
          postgres_user           => $postgres_user,
          redis_host              => $redis_host,
          redis_port              => $redis_port,
          log_level               => $log_level,
          error_reporting_enabled => $error_reporting_enabled,
          email_host              => $email_host,
          email_port              => $email_port,
          email_username          => $email_username,
          email_password          => $_email_password,
          email_from              => $email_from,
          email_use_tls           => $email_use_tls,
          email_use_ssl           => $email_use_ssl,
          geoip_enabled           => $geoip_enabled,
          geoip_account_id        => $geoip_account_id,
          geoip_license_key       => $_geoip_license_key,
      }),
      require => File[$authentik_dir],
    }

    # Ensure docker-compose stack is running
    exec { 'start-authentik':
      command => 'docker compose up -d',
      cwd     => $authentik_dir,
      path    => ['/usr/bin', '/usr/local/bin', '/usr/sbin', '/bin', '/sbin', '/snap/bin'],
      unless  => "docker ps --format '{{.Names}}' | grep -q '^authentik-server'",
      require => [
        File["${authentik_dir}/docker-compose.yaml"],
        File["${authentik_dir}/.env"],
      ],
    }

    # Restart containers when configuration changes
    exec { 'restart-authentik':
      command     => 'docker compose up -d --force-recreate --remove-orphans',
      cwd         => $authentik_dir,
      path        => ['/usr/bin', '/usr/local/bin', '/usr/sbin', '/bin', '/sbin', '/snap/bin'],
      refreshonly => true,
      subscribe   => [
        File["${authentik_dir}/docker-compose.yaml"],
        File["${authentik_dir}/.env"],
      ],
    }
  }
}
