# @summary PuppetDB installation and configuration
#
# This profile installs and configures PuppetDB on the Puppet Server for
# exported resources support. PuppetDB stores facts, catalogs, and reports
# from all managed nodes and enables features like exported resources which
# are required by the markt/acme module for certificate management.
#
# @param manage_puppetdb
#   Whether to manage PuppetDB on this node
#
# @param postgres_host
#   PostgreSQL server hostname (default: localhost)
#
# @param postgres_port
#   PostgreSQL server port (default: 5432)
#
# @param postgres_database
#   PostgreSQL database name for PuppetDB
#
# @param postgres_username
#   PostgreSQL username for PuppetDB
#
# @param postgres_password
#   PostgreSQL password for PuppetDB (use Sensitive type)
#
# @param puppetdb_version
#   PuppetDB version to install (default: installed, can specify version)
#
# @param java_args
#   JVM arguments for PuppetDB (memory tuning)
#
# @example Basic usage via Hiera or Foreman ENC
#   profile::puppetdb::manage_puppetdb: true
#   profile::puppetdb::postgres_password: 'ENC[PKCS7,...]'
#
class profile::puppetdb (
  Boolean $manage_puppetdb = false,
  String[1] $postgres_host = 'localhost',
  Variant[String[1], Integer[1024,65535]] $postgres_port = 5432,
  String[1] $postgres_database = 'puppetdb',
  String[1] $postgres_username = 'puppetdb',
  String[1] $postgres_password = 'changeme',
  String[1] $puppetdb_version = 'installed',
  Hash[String, Scalar] $java_args = {
    '-Xmx' => '2g',  # 2GB max heap (adjust based on infrastructure size)
    '-Xms' => '1g',  # 1GB initial heap
  },
) {
  # PuppetDB module expects port as String (for scanf function)
  $postgres_port_str = String($postgres_port)
  $postgres_password_sensitive = Sensitive($postgres_password)

  if $manage_puppetdb {
    # Install and configure PuppetDB
    class { 'puppetdb':
      database_host     => $postgres_host,
      database_port     => $postgres_port_str,
      database_name     => $postgres_database,
      database_username => $postgres_username,
      database_password => $postgres_password_sensitive.unwrap,
      java_args         => $java_args,
      manage_dbserver   => false,  # PostgreSQL managed by profile::postgresql
    }

    # Configure Puppet Server to use PuppetDB for storeconfigs
    # This enables exported resources (@@resource) and PuppetDB integration
    # NOTE: Both storeconfigs and reports are managed by puppet module to avoid
    # section conflicts ([server] vs [master])
    class { 'puppetdb::master::config':
      puppetdb_server         => $facts['networking']['fqdn'],
      puppetdb_port           => 8081,
      manage_report_processor => false,  # Managed by puppet module (server_reports) to avoid section conflict
      manage_storeconfigs     => false,  # Managed by puppet module (server_storeconfigs) to avoid section conflict
      strict_validation       => true,
      enable_reports          => true,
      restart_puppet          => false,  # Don't manage service - puppet module already does
    }

    # Ordering to ensure PuppetDB is ready before Puppet Server connects
    Class['puppetdb']
      -> Class['puppetdb::master::config']
  }
}
