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
class profile::puppetdb {
  # Use profile::param() to support both Hiera and Foreman ENC Smart Class Parameters
  $manage_puppetdb = profile::param('profile::puppetdb::manage_puppetdb', Boolean, false)
  $postgres_host = profile::param('profile::puppetdb::postgres_host', String[1], 'localhost')
  $postgres_port_raw = profile::param('profile::puppetdb::postgres_port', Variant[String[1], Integer[1024,65535]], 5432)
  # PuppetDB module expects port as String (for scanf function)
  $postgres_port = String($postgres_port_raw)
  $postgres_database = profile::param('profile::puppetdb::postgres_database', String[1], 'puppetdb')
  $postgres_username = profile::param('profile::puppetdb::postgres_username', String[1], 'puppetdb')
  $postgres_password_raw = profile::param('profile::puppetdb::postgres_password', String[1], 'changeme')
  $postgres_password = Sensitive($postgres_password_raw)
  $puppetdb_version = profile::param('profile::puppetdb::puppetdb_version', String[1], 'installed')
  $java_args = profile::param('profile::puppetdb::java_args', Hash[String, Scalar], {
    '-Xmx' => '2g',  # 2GB max heap (adjust based on infrastructure size)
    '-Xms' => '1g',  # 1GB initial heap
  })

  if $manage_puppetdb {
    # Install and configure PuppetDB
    class { 'puppetdb':
      database_host     => $postgres_host,
      database_port     => $postgres_port,
      database_name     => $postgres_database,
      database_username => $postgres_username,
      database_password => $postgres_password.unwrap,
      java_args         => $java_args,
      manage_dbserver   => false,  # PostgreSQL managed by profile::postgresql
    }

    # Configure Puppet Server to use PuppetDB for storeconfigs
    # This enables exported resources (@@resource) and PuppetDB integration
    class { 'puppetdb::master::config':
      puppetdb_server         => $facts['networking']['fqdn'],
      puppetdb_port           => 8081,
      manage_report_processor => true,
      manage_storeconfigs     => true,
      strict_validation       => true,
      enable_reports          => true,
      restart_puppet          => false,  # Don't manage service - puppet module already does
      manage_puppetserver     => false,  # Don't manage puppetserver service
    }

    # Ordering to ensure PuppetDB is ready before Puppet Server connects
    Class['puppetdb']
      -> Class['puppetdb::master::config']
  }
}
