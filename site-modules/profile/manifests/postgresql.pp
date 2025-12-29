# @summary Manages PostgreSQL database server
#
# This profile manages PostgreSQL installation and configuration for backend
# database services. It wraps the puppetlabs-postgresql module and provides
# a data-driven interface for managing databases, users, and grants.
#
# @param manage_postgresql
#   Whether to manage PostgreSQL installation (default: false)
# @param postgres_version
#   PostgreSQL major version to install (default: '13')
# @param listen_addresses
#   Comma-separated list of IP addresses to listen on (default: 'localhost')
# @param port
#   PostgreSQL server port (default: 5432)
# @param manage_firewall
#   Whether to manage firewall rules for PostgreSQL (default: false)
# @param allowed_sources
#   Array of source IP addresses/networks allowed to connect (for pg_hba.conf)
# @param databases
#   Hash of databases to create with puppetlabs-postgresql::server::db
#   Format: { 'dbname' => { owner => 'username', encoding => 'UTF8', ... } }
# @param database_users
#   Hash of database users to create with puppetlabs-postgresql::server::role
#   Format: { 'username' => { password_hash => 'encrypted', ... } }
# @param database_grants
#   Hash of database grants to create with puppetlabs-postgresql::server::database_grant
#   Format: { 'grant_name' => { privilege => 'ALL', db => 'dbname', role => 'user' } }
# @param data_dir
#   PostgreSQL data directory (OS-dependent default)
# @param manage_package_repo
#   Whether to manage PostgreSQL package repository (default: true)
#
# @example Basic usage with Hiera
#   profile::postgresql::manage_postgresql: true
#   profile::postgresql::postgres_version: '13'
#   profile::postgresql::databases:
#     foreman:
#       owner: foreman
#       encoding: UTF8
#   profile::postgresql::database_users:
#     foreman:
#       password_hash: 'ENC[PKCS7,...]'
#
class profile::postgresql (
  Boolean                                 $manage_postgresql     = false,
  String[1]                               $postgres_version      = '13',
  String[1]                               $listen_addresses      = 'localhost',
  Integer[1,65535]                        $port                  = 5432,
  Boolean                                 $manage_firewall       = false,
  Array[Stdlib::IP::Address]              $allowed_sources       = [],
  Hash[String[1], Hash]                   $databases             = {},
  Hash[String[1], Hash]                   $database_users        = {},
  Hash[String[1], Hash]                   $database_grants       = {},
  Optional[Stdlib::Absolutepath]          $data_dir              = undef,
  Boolean                                 $manage_package_repo   = true,
) {
  if $manage_postgresql {
    # Main PostgreSQL server class
    class { 'postgresql::server':
      listen_addresses           => $listen_addresses,
      port                       => $port,
      ip_mask_deny_postgres_user => '0.0.0.0/32',  # Deny postgres user from network
      ip_mask_allow_all_users    => '0.0.0.0/32',  # Control via pg_hba_rule instead
      encoding                   => 'UTF8',
      locale                     => 'en_US.UTF-8',
    }

    # Configure pg_hba for md5 authentication on local connections
    postgresql::server::pg_hba_rule { 'local access with md5':
      type        => 'local',
      database    => 'all',
      user        => 'all',
      auth_method => 'md5',
      order       => '001',
    }

    # Create databases from Hiera
    $databases.each |String $db_name, Hash $db_config| {
      # Transform 'owner' to 'user' for postgresql::server::db compatibility
      $db_params = $db_config.map |$key, $value| {
        if $key == 'owner' {
          ['user', $value]
        } else {
          [$key, $value]
        }
      }

      postgresql::server::db { $db_name:
        *       => Hash($db_params),
        require => Class['postgresql::server'],
      }
    }

    # Create database users from Hiera
    $database_users.each |String $username, Hash $user_config| {
      # Transform 'password' to 'password_hash' for postgresql::server::role compatibility
      $user_params = $user_config.map |$key, $value| {
        if $key == 'password' {
          ['password_hash', postgresql_password($username, $value)]
        } else {
          [$key, $value]
        }
      }

      postgresql::server::role { $username:
        *       => Hash($user_params),
        require => Class['postgresql::server'],
      }
    }

    # Create database grants from Hiera
    $database_grants.each |String $grant_name, Hash $grant_config| {
      postgresql::server::database_grant { $grant_name:
        *       => $grant_config,
        require => Class['postgresql::server'],
      }
    }

    # Optional: Manage firewall rules for PostgreSQL
    if $manage_firewall and !empty($allowed_sources) {
      $allowed_sources.each |Stdlib::IP::Address $source| {
        firewall { "100 allow PostgreSQL from ${source}":
          dport  => $port,
          proto  => 'tcp',
          source => $source,
          action => 'accept',
        }
      }
    }
  }
}
