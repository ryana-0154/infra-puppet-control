# @summary Deploy Let's Encrypt certificates to nodes
#
# This profile deploys Let's Encrypt certificates from the central ACME server
# (Puppet Server) to nodes that need them. Certificates are fetched via exported
# resources from PuppetDB and installed with proper permissions.
#
# Private keys remain on the target host for security - they are never stored
# on the Puppet Server. The ACME server only manages the certificate request
# and renewal process.
#
# @param manage_deploy
#   Whether to deploy certificates on this node
#
# @param deploy_certificates
#   Hash of certificates to deploy to this node
#   Format: { 'cert_name' => { path => '/path', user => 'owner', ... } }
#
# @param base_cert_path
#   Base directory where certificates will be stored (default: /etc/ssl/letsencrypt)
#
# @param ssl_group
#   Group ownership for certificate files (default: ssl-cert)
#
# @example Deploy wildcard certificate to VPS
#   profile::acme_deploy::manage_deploy: true
#   profile::acme_deploy::deploy_certificates:
#     wildcard_ra_home:
#       user: 'root'
#       group: 'ssl-cert'
#       key_mode: '0640'
#       cert_mode: '0644'
#       post_refresh_cmd: 'systemctl reload nginx'
#
class profile::acme_deploy (
  Boolean $manage_deploy = false,
  Hash[String, Hash] $deploy_certificates = {},
  Stdlib::Absolutepath $base_cert_path = '/etc/ssl/letsencrypt',
  String[1] $ssl_group = 'ssl-cert',
) {
  if $manage_deploy {
    # Ensure base certificate directory exists
    file { $base_cert_path:
      ensure => directory,
      owner  => 'root',
      group  => 'root',
      mode   => '0755',
    }

    # Ensure ssl-cert group exists for certificate access
    group { $ssl_group:
      ensure => present,
      system => true,
    }

    # Deploy each certificate from Hiera configuration
    $deploy_certificates.each |String $cert_name, Hash $deploy_config| {
      # Merge defaults with per-certificate configuration
      $cert_defaults = {
        'path'             => "${base_cert_path}/${cert_name}",
        'user'             => 'root',
        'group'            => $ssl_group,
        'key_mode'         => '0640',  # Private key: owner read-write, group read
        'cert_mode'        => '0644',  # Certificate: world-readable
        'post_refresh_cmd' => undef,   # Command to run after cert renewal
      }
      $cert_params = $cert_defaults + $deploy_config

      # Use acme::deploy resource to fetch certificate from Puppet Server
      # This uses exported resources from PuppetDB
      acme::deploy { $cert_name:
        path             => $cert_params['path'],
        user             => $cert_params['user'],
        group            => $cert_params['group'],
        key_mode         => $cert_params['key_mode'],
        cert_mode        => $cert_params['cert_mode'],
        post_refresh_cmd => $cert_params['post_refresh_cmd'],
        require          => [
          File[$base_cert_path],
          Group[$ssl_group],
        ],
      }
    }
  }
}
