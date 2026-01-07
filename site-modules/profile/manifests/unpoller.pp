# @summary Standalone UniFi Poller for network device metrics
#
# This profile sets up UniFi Poller as a standalone container to collect
# metrics from UniFi network devices (UDM, UDR, switches, APs). The metrics
# are exposed via Prometheus endpoint for scraping by external collectors.
#
# @note Requirements
#   - Docker must be installed and running
#
# @param manage_unpoller
#   Whether to manage UniFi Poller configuration
# @param unpoller_dir
#   Directory for UniFi Poller configuration and data
# @param unpoller_image
#   Docker image for UniFi Poller
# @param unpoller_port
#   Port for Prometheus metrics endpoint
# @param bind_address
#   IP address to bind the metrics endpoint to
# @param unpoller_url
#   URL of UniFi controller (e.g., https://192.168.1.1 or https://10.10.10.2)
# @param unpoller_user
#   Username for UniFi controller read-only user
# @param unpoller_pass
#   Password for UniFi controller user (should be encrypted with eyaml)
# @param unpoller_save_dpi
#   Whether to save DPI (Deep Packet Inspection) data from UniFi controller
# @param unpoller_verify_ssl
#   Whether to verify SSL certificate of UniFi controller
# @param unpoller_sites
#   Array of UniFi sites to poll (default: ['all'] for all sites)
#
# @example Basic usage with Hiera
#   profile::unpoller::manage_unpoller: true
#   profile::unpoller::unpoller_url: 'https://10.10.10.2'
#   profile::unpoller::unpoller_user: 'unifipoller'
#   profile::unpoller::unpoller_pass: >
#     ENC[PKCS7,MII...]
#
# @example With custom bind address
#   class { 'profile::unpoller':
#     manage_unpoller => true,
#     unpoller_url    => 'https://192.168.1.1',
#     unpoller_user   => 'metrics',
#     unpoller_pass   => Sensitive('secret'),
#     bind_address    => '10.10.10.5',
#   }
#
class profile::unpoller (
  Boolean                        $manage_unpoller    = false,
  Stdlib::Absolutepath           $unpoller_dir       = '/opt/unpoller',
  String[1]                      $unpoller_image     = 'ghcr.io/unpoller/unpoller:latest',
  Integer[1,65535]               $unpoller_port      = 9130,
  String[1]                      $bind_address       = '0.0.0.0',

  # UniFi Controller configuration
  Optional[String[1]]            $unpoller_url       = undef,
  Optional[String[1]]            $unpoller_user      = undef,
  Optional[Variant[String[1], Sensitive[String[1]]]] $unpoller_pass = undef,
  Boolean                        $unpoller_save_dpi  = false,
  Boolean                        $unpoller_verify_ssl = false,
  Array[String[1]]               $unpoller_sites     = ['all'],
) {
  # Multi-source parameter resolution (Foreman ENC -> Hiera -> Defaults)
  $_manage_unpoller_enc = getvar('unpoller_manage_unpoller')
  $_manage_unpoller = $_manage_unpoller_enc ? {
    undef   => $manage_unpoller,
    default => $_manage_unpoller_enc,
  }

  $_unpoller_url_enc = getvar('unpoller_url')
  $_unpoller_url_hiera = lookup('profile::unpoller::unpoller_url', Optional[String], 'first', undef)
  $_unpoller_url = $_unpoller_url_enc ? {
    undef   => $_unpoller_url_hiera ? {
      undef   => $unpoller_url,
      default => $_unpoller_url_hiera,
    },
    default => $_unpoller_url_enc,
  }

  $_unpoller_user_enc = getvar('unpoller_user')
  $_unpoller_user_hiera = lookup('profile::unpoller::unpoller_user', Optional[String], 'first', undef)
  $_unpoller_user = $_unpoller_user_enc ? {
    undef   => $_unpoller_user_hiera ? {
      undef   => $unpoller_user,
      default => $_unpoller_user_hiera,
    },
    default => $_unpoller_user_enc,
  }

  # Handle sensitive password
  $_unpoller_pass_raw = getvar('unpoller_pass')
  $_unpoller_pass_hiera = lookup('profile::unpoller::unpoller_pass', Optional[Variant[String, Sensitive[String]]], 'first', undef)
  $_unpoller_pass_hiera_wrapped = $_unpoller_pass_hiera ? {
    Sensitive => $_unpoller_pass_hiera,
    String    => Sensitive($_unpoller_pass_hiera),
    default   => undef,
  }
  $_unpoller_pass_param = $unpoller_pass ? {
    Sensitive => $unpoller_pass,
    String    => Sensitive($unpoller_pass),
    default   => undef,
  }
  $_unpoller_pass = $_unpoller_pass_raw ? {
    undef   => $_unpoller_pass_hiera_wrapped ? {
      undef   => $_unpoller_pass_param,
      default => $_unpoller_pass_hiera_wrapped,
    },
    default => Sensitive($_unpoller_pass_raw),
  }

  # Validate required parameters when enabled
  if $_manage_unpoller {
    if !$_unpoller_url or !$_unpoller_user or !$_unpoller_pass {
      fail('profile::unpoller: unpoller_url, unpoller_user, and unpoller_pass are required when manage_unpoller is true')
    }

    # Ensure Docker Compose v2 is installed
    ensure_packages(['docker-compose-plugin'])

    # Create UnPoller directory
    file { $unpoller_dir:
      ensure => directory,
      owner  => 'root',
      group  => 'root',
      mode   => '0755',
    }

    # Determine hostname for labels
    $hostname = $facts['networking']['fqdn'] ? {
      undef   => $facts['networking']['hostname'] ? {
        undef   => 'unknown',
        default => $facts['networking']['hostname'],
      },
      default => $facts['networking']['fqdn'],
    }

    # Docker Compose file
    file { "${unpoller_dir}/docker-compose.yaml":
      ensure  => file,
      owner   => 'root',
      group   => 'root',
      mode    => '0644',
      content => epp('profile/unpoller/docker-compose.yaml.epp', {
        unpoller_image      => $unpoller_image,
        unpoller_port       => $unpoller_port,
        bind_address        => $bind_address,
        unpoller_url        => $_unpoller_url,
        unpoller_user       => $_unpoller_user,
        unpoller_pass       => $_unpoller_pass,
        unpoller_save_dpi   => $unpoller_save_dpi,
        unpoller_verify_ssl => $unpoller_verify_ssl,
        unpoller_sites      => $unpoller_sites,
      }),
      require => File[$unpoller_dir],
    }

    # Ensure UnPoller container is running
    exec { 'start-unpoller':
      command => 'docker compose up -d',
      cwd     => $unpoller_dir,
      path    => ['/usr/bin', '/usr/local/bin', '/usr/sbin', '/bin', '/sbin', '/snap/bin'],
      unless  => "docker ps --format '{{.Names}}' | grep -q '^unpoller$'",
      require => File["${unpoller_dir}/docker-compose.yaml"],
    }

    # Restart container when configuration changes
    exec { 'restart-unpoller':
      command     => 'docker compose up -d --force-recreate',
      cwd         => $unpoller_dir,
      path        => ['/usr/bin', '/usr/local/bin', '/usr/sbin', '/bin', '/sbin', '/snap/bin'],
      refreshonly => true,
      subscribe   => File["${unpoller_dir}/docker-compose.yaml"],
    }
  }
}
