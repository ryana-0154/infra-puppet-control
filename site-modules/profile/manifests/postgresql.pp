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
      postgres_password          => undef,  # Disable default postgres user password
      ipv4acl                   => ['local all all md5'],  # Require password authentication
      listen_addresses          => $listen_addresses,
      port                      => $port,
      manage_package_repo       => $manage_package_repo,
      postgres_version          => $postgres_version,
      datadir                   => $data_dir,
    }

    # Create databases from Hiera
    $databases.each |String $db_name, Hash $db_config| {
      postgresql::server::db { $db_name:
        *       => $db_config,
        require => Class['postgresql::server'],
      }
    }

    # Create database users from Hiera
    $database_users.each |String $username, Hash $user_config| {
      postgresql::server::role { $username:
        *       => $user_config,
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
