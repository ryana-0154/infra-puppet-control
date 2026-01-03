# @summary Nginx reverse proxy with SSL termination
#
# This profile configures Nginx as a reverse proxy with SSL/TLS termination
# for web services (Grafana, Authelia, etc.). It uses Let's Encrypt certificates
# deployed via profile::acme_deploy.
#
# The proxy provides:
# - HTTPS termination with modern TLS configuration
# - HTTP to HTTPS redirect
# - Reverse proxy to backend services
# - Security headers and best practices
#
# @param manage_nginx
#   Whether to manage Nginx on this node
#
# @param ssl_cert_path
#   Path to SSL certificate fullchain file
#
# @param ssl_key_path
#   Path to SSL private key file
#
# @param proxy_vhosts
#   Hash of virtual hosts to configure
#   Format: { 'vhost_name' => { server_name => [...], proxy => 'http://...' } }
#
# @param ssl_protocols
#   TLS protocols to enable (modern security: TLSv1.2 and TLSv1.3 only)
#
# @param ssl_ciphers
#   TLS cipher suites (modern security)
#
# @param enable_http_redirect
#   Redirect HTTP (port 80) to HTTPS (default: true)
#
# @example Basic reverse proxy for Grafana
#   profile::nginx_proxy::manage_nginx: true
#   profile::nginx_proxy::proxy_vhosts:
#     grafana:
#       server_name: ['grafana.ra-home.co.uk']
#       proxy: 'http://localhost:3000'
#       proxy_set_header:
#         - 'Host $host'
#         - 'X-Real-IP $remote_addr'
#         - 'X-Forwarded-Proto $scheme'
#
class profile::nginx_proxy (
  Boolean $manage_nginx = false,
  Stdlib::Absolutepath $ssl_cert_path = '/etc/ssl/letsencrypt/wildcard_ra_home/fullchain.pem',
  Stdlib::Absolutepath $ssl_key_path = '/etc/ssl/letsencrypt/wildcard_ra_home/privkey.pem',
  Hash[String, Hash] $proxy_vhosts = {},
  Array[String[1]] $ssl_protocols = ['TLSv1.2', 'TLSv1.3'],
  String[1] $ssl_ciphers = 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384',
  Boolean $enable_http_redirect = true,
) {
  if $manage_nginx {
    # Install and configure Nginx
    class { 'nginx':
      manage_repo    => true,
      package_source => 'nginx-stable',  # Use official Nginx repository
      confd_purge    => true,  # Remove unmanaged config files
      server_purge   => true,  # Remove unmanaged server blocks
    }

    # Configure global SSL settings
    nginx::resource::server { 'default':
      server_name         => ['_'],
      listen_port         => 80,
      ipv6_listen_port    => 80,
      ssl                 => false,
      www_root            => '/var/www/html',
      index_files         => [],
      location_cfg_append => {
        'return' => '444',  # Drop connections to unknown hosts
      },
    }

    # HTTP to HTTPS redirect (if enabled)
    if $enable_http_redirect {
      nginx::resource::server { 'http_redirect':
        listen_port         => 80,
        ipv6_listen_port    => 80,
        ssl                 => false,
        server_name         => $proxy_vhosts.keys.map |$name| {
          $proxy_vhosts[$name]['server_name']
        }.flatten.unique,
        location_cfg_append => {
          'return' => '301 https://$host$request_uri',
        },
      }
    }

    # Create HTTPS virtual hosts from Hiera
    $proxy_vhosts.each |String $vhost_name, Hash $vhost_config| {
      # Merge defaults with per-vhost configuration
      $vhost_defaults = {
        'listen_port'           => 443,
        'ipv6_listen_port'      => 443,
        'ssl'                   => true,
        'ssl_cert'              => $ssl_cert_path,
        'ssl_key'               => $ssl_key_path,
        'ssl_protocols'         => join($ssl_protocols, ' '),
        'ssl_ciphers'           => $ssl_ciphers,
        'ssl_prefer_server_ciphers' => 'on',
        'http2'                 => 'on',
        'add_header'            => {
          'Strict-Transport-Security' => 'max-age=31536000; includeSubDomains',
          'X-Frame-Options'           => 'SAMEORIGIN',
          'X-Content-Type-Options'    => 'nosniff',
          'X-XSS-Protection'          => '1; mode=block',
        },
        'proxy_http_version'    => '1.1',
        'proxy_set_header'      => [
          'Host $host',
          'X-Real-IP $remote_addr',
          'X-Forwarded-For $proxy_add_x_forwarded_for',
          'X-Forwarded-Proto $scheme',
          'X-Forwarded-Host $host',
          'X-Forwarded-Port $server_port',
        ],
      }
      $merged_config = $vhost_defaults + $vhost_config

      nginx::resource::server { $vhost_name:
        * => $merged_config,
      }
    }

    # Ensure Nginx reloads when certificates are renewed
    # This is handled by post_refresh_cmd in acme_deploy profile
  }
}
