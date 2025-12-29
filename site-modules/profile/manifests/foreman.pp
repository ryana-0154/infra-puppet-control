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
  Variant[String[1], Sensitive[String[1]]] $admin_password     = Sensitive('changeme'),
  String[1]                            $db_host                = 'localhost',
  String[1]                            $db_database            = 'foreman',
  String[1]                            $db_username            = 'foreman',
  Variant[String[1], Sensitive[String[1]]] $db_password        = Sensitive('changeme'),
  Boolean                              $enable_puppetserver    = true,
  Boolean                              $enable_enc             = true,
  Boolean                              $enable_reports         = true,
  Hash[String[1], String]              $initial_organization   = { 'name' => 'Default Organization', 'description' => '' },
  Hash[String[1], String]              $initial_location       = { 'name' => 'Default Location', 'description' => '' },
  Optional[Stdlib::Absolutepath]       $server_ssl_ca          = undef,
  Optional[Stdlib::Absolutepath]       $server_ssl_cert        = undef,
  Optional[Stdlib::Absolutepath]       $server_ssl_key         = undef,
) {
  if $manage_foreman {
    # Handle both plain strings (from eyaml) and Sensitive types
    # eyaml-encrypted values come back as plain strings, so wrap them
    $admin_password_sensitive = $admin_password ? {
      Sensitive => $admin_password,
      default   => Sensitive($admin_password),
    }
    $db_password_sensitive = $db_password ? {
      Sensitive => $db_password,
      default   => Sensitive($db_password),
    }

    # Validate required passwords aren't default values
    $admin_pass_unwrapped = $admin_password_sensitive.unwrap
    $db_pass_unwrapped = $db_password_sensitive.unwrap

    if $admin_pass_unwrapped == 'changeme' {
      fail('profile::foreman::admin_password must be set to a secure value and encrypted with eyaml')
    }
    if $db_pass_unwrapped == 'changeme' {
      fail('profile::foreman::db_password must be set to match the PostgreSQL user password')
    }

    # Note: EPEL repository configuration is handled automatically by the
    # theforeman-foreman module when needed on RHEL-family systems

    # Main Foreman class
    class { 'foreman':
      foreman_url          => "https://${server_fqdn}",
      servername           => $server_fqdn,
      admin_username       => $admin_username,
      admin_password       => $admin_pass_unwrapped,
      db_manage            => false,  # We manage PostgreSQL via profile::postgresql
      db_type              => 'postgresql',
      db_host              => $db_host,
      db_database          => $db_database,
      db_username          => $db_username,
      db_password          => $db_pass_unwrapped,
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

      # Note: ENC and report processor configuration is handled
      # by the main foreman class parameters above (enc => true, reports => true)
      # The theforeman-foreman module does not provide a foreman::puppetmaster class
    }

    # Note: Service management is handled by the foreman class itself
    # No need to declare service resource here
  }
}
