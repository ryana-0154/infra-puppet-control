# @summary Manages Foreman server installation and configuration
#
# This profile manages Foreman as an External Node Classifier (ENC) for Puppet
# with web UI, database backend integration, and Puppet Server configuration.
# It wraps the theforeman-foreman module to provide data-driven configuration.
#
# @param manage_foreman
#   Whether to manage Foreman installation (default: false)
# @param foreman_version
#   Foreman version to install (default: 'nightly', or specify like '3.7')
# @param server_fqdn
#   Fully qualified domain name for the Foreman server
# @param admin_username
#   Foreman admin username (default: 'admin')
# @param admin_password
#   Foreman admin password (Sensitive type, must be encrypted with eyaml)
# @param db_host
#   Database server hostname (default: 'localhost')
# @param db_database
#   Database name for Foreman (default: 'foreman')
# @param db_username
#   Database username for Foreman (default: 'foreman')
# @param db_password
#   Database password for Foreman (Sensitive type, must be encrypted with eyaml)
# @param enable_puppetserver
#   Whether to install and configure Puppet Server (default: true)
# @param enable_enc
#   Whether to enable External Node Classifier functionality (default: true)
# @param enable_reports
#   Whether to enable Puppet report processing (default: true)
# @param configure_epel_repo
#   Whether to configure EPEL repository (needed on RHEL-family) (default: true)
# @param initial_organization
#   Hash defining the initial organization { name => 'Org Name', description => '...' }
# @param initial_location
#   Hash defining the initial location { name => 'Location Name', description => '...' }
# @param server_ssl_ca
#   Path to SSL CA certificate (default: Puppet CA)
# @param server_ssl_cert
#   Path to SSL server certificate (default: Puppet server cert)
# @param server_ssl_key
#   Path to SSL private key (default: Puppet server key)
#
# @example Basic usage with Hiera
#   profile::foreman::manage_foreman: true
#   profile::foreman::server_fqdn: 'foreman.example.com'
#   profile::foreman::admin_password: 'ENC[PKCS7,...]'
#   profile::foreman::db_password: 'ENC[PKCS7,...]'
#   profile::foreman::enable_puppetserver: true
#   profile::foreman::enable_enc: true
#
class profile::foreman (
  Boolean                              $manage_foreman         = false,
  String[1]                            $foreman_version        = 'nightly',
  String[1]                            $server_fqdn            = $facts['networking']['fqdn'],
  String[1]                            $admin_username         = 'admin',
  Sensitive[String[1]]                 $admin_password         = Sensitive('changeme'),
  String[1]                            $db_host                = 'localhost',
  String[1]                            $db_database            = 'foreman',
  String[1]                            $db_username            = 'foreman',
  Sensitive[String[1]]                 $db_password            = Sensitive('changeme'),
  Boolean                              $enable_puppetserver    = true,
  Boolean                              $enable_enc             = true,
  Boolean                              $enable_reports         = true,
  Boolean                              $configure_epel_repo    = true,
  Hash[String[1], String[1]]           $initial_organization   = { 'name' => 'Default Organization', 'description' => '' },
  Hash[String[1], String[1]]           $initial_location       = { 'name' => 'Default Location', 'description' => '' },
  Optional[Stdlib::Absolutepath]       $server_ssl_ca          = undef,
  Optional[Stdlib::Absolutepath]       $server_ssl_cert        = undef,
  Optional[Stdlib::Absolutepath]       $server_ssl_key         = undef,
) {
  if $manage_foreman {
    # Validate required Sensitive parameters aren't default values
    if $admin_password.unwrap == 'changeme' {
      fail('profile::foreman::admin_password must be set to a secure value and encrypted with eyaml')
    }
    if $db_password.unwrap == 'changeme' {
      fail('profile::foreman::db_password must be set to match the PostgreSQL user password')
    }

    # Configure EPEL repository (required for RHEL-family systems)
    if $configure_epel_repo and $facts['os']['family'] == 'RedHat' {
      class { 'foreman::repos':
        repo => 'stable',
      }
    }

    # Main Foreman class
    class { 'foreman':
      foreman_url          => "https://${server_fqdn}",
      servername           => $server_fqdn,
      admin_username       => $admin_username,
      admin_password       => $admin_password.unwrap,
      db_manage            => false,  # We manage PostgreSQL via profile::postgresql
      db_type              => 'postgresql',
      db_host              => $db_host,
      db_database          => $db_database,
      db_username          => $db_username,
      db_password          => $db_password.unwrap,
      configure_epel_repo  => false,  # Already configured above
      initial_organization => $initial_organization['name'],
      initial_location     => $initial_location['name'],
      server_ssl_ca        => pick($server_ssl_ca, '/etc/puppetlabs/puppet/ssl/certs/ca.pem'),
      server_ssl_cert      => pick($server_ssl_cert, "/etc/puppetlabs/puppet/ssl/certs/${server_fqdn}.pem"),
      server_ssl_key       => pick($server_ssl_key, "/etc/puppetlabs/puppet/ssl/private_keys/${server_fqdn}.pem"),
      require              => Class['postgresql::server'],
    }

    # Configure Puppet Server integration if enabled
    if $enable_puppetserver {
      class { 'foreman::plugin::puppet':
        ensure => 'installed',
      }

      # Configure Puppet Server ENC integration
      if $enable_enc {
        class { 'foreman::puppetmaster':
          enc_api       => true,
          enc_ssl_ca    => pick($server_ssl_ca, '/etc/puppetlabs/puppet/ssl/certs/ca.pem'),
          enc_ssl_cert  => pick($server_ssl_cert, "/etc/puppetlabs/puppet/ssl/certs/${server_fqdn}.pem"),
          enc_ssl_key   => pick($server_ssl_key, "/etc/puppetlabs/puppet/ssl/private_keys/${server_fqdn}.pem"),
          reports       => $enable_reports,
          puppet_home   => '/etc/puppetlabs/puppet',
          puppet_etcdir => '/etc/puppetlabs/puppet',
          require       => Class['foreman'],
        }
      }
    }

    # Ensure Foreman service is running
    service { 'foreman':
      ensure  => running,
      enable  => true,
      require => Class['foreman'],
    }
  }
}
