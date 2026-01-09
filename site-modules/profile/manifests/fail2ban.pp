# @summary Manages fail2ban intrusion prevention system
#
# This profile manages fail2ban for protecting services from brute-force attacks.
# It provides default protection for SSH and optionally HTTP/HTTPS, with support
# for custom jails, filters, and actions.
#
# @param manage_fail2ban
#   Whether to manage fail2ban. Set to false to disable completely.
# @param package_ensure
#   Package state for fail2ban (present, latest, absent)
# @param service_ensure
#   Service state for fail2ban (running, stopped)
# @param service_enable
#   Whether to enable fail2ban service at boot
# @param bantime
#   Duration to ban an IP address (e.g., '1h', '24h', '1w')
# @param findtime
#   Time window for counting failed attempts (e.g., '10m', '1h')
# @param maxretry
#   Number of failed attempts before banning
# @param destemail
#   Email address for ban notifications (optional)
# @param sender
#   Email sender address for notifications (optional)
# @param action
#   Default action template (action_, action_mw, action_mwl)
# @param enable_ssh_jail
#   Whether to enable SSH jail protection
# @param enable_http_jails
#   Whether to enable HTTP/HTTPS DoS protection jails
# @param ssh_port
#   SSH port to monitor (shared parameter from Foreman)
# @param http_logpath
#   Array of HTTP/HTTPS log file paths to monitor
# @param custom_jails
#   Hash of custom jail configurations
# @param custom_filters
#   Hash of custom filter definitions
# @param custom_actions
#   Hash of custom action definitions
#
# @example Basic usage
#   include profile::fail2ban
#
class profile::fail2ban (
  Boolean $manage_fail2ban                   = true,
  String[1] $package_ensure                  = 'present',
  Enum['running', 'stopped'] $service_ensure = 'running',
  Boolean $service_enable                    = true,
  String[1] $bantime                         = '1h',
  String[1] $findtime                        = '10m',
  Integer[1] $maxretry                       = 5,
  Optional[String[1]] $destemail             = undef,
  Optional[String[1]] $sender                = undef,
  String[1] $action                          = 'action_',
  Boolean $enable_ssh_jail                   = true,
  Boolean $enable_http_jails                 = true,
  Integer[1, 65535] $ssh_port                = 22,
  Array[String[1]] $http_logpath             = ['/var/log/nginx/access.log', '/var/log/apache2/access.log'],
  Hash[String[1], Hash] $custom_jails        = {},
  Hash[String[1], Hash] $custom_filters      = {},
  Hash[String[1], Hash] $custom_actions      = {},
) {
  # Foreman ENC -> Hiera (via APL) -> Default resolution
  $_manage_fail2ban_enc = getvar('fail2ban_manage')
  $_manage_fail2ban = $_manage_fail2ban_enc ? {
    undef   => $manage_fail2ban,
    default => $_manage_fail2ban_enc,
  }

  # SSH port - shared parameter used by multiple profiles (wireguard, fail2ban, ssh_hardening)
  $_ssh_port_enc = getvar('ssh_port')
  $_ssh_port_raw = $_ssh_port_enc ? {
    undef   => $ssh_port,
    default => $_ssh_port_enc,
  }
  # Handle string conversion from Foreman
  $_ssh_port = $_ssh_port_raw ? {
    String  => Integer($_ssh_port_raw),
    default => $_ssh_port_raw,
  }

  if $_manage_fail2ban {
    # Determine SSH log path based on OS family
    $ssh_logpath = $facts['os']['family'] ? {
      'Debian' => '/var/log/auth.log',
      'RedHat' => '/var/log/secure',
      default  => '/var/log/auth.log',
    }

    # Build jails hash based on enabled features
    $base_jails = {}

    # Add SSH jail if enabled
    $ssh_jail = $enable_ssh_jail ? {
      true => {
        'sshd' => {
          'enabled'  => true,
          'port'     => $_ssh_port,
          'logpath'  => $ssh_logpath,
          'maxretry' => $maxretry,
          'bantime'  => $bantime,
          'findtime' => $findtime,
        },
      },
      default => {},
    }

    # Add HTTP DoS jails if enabled
    $http_jails = $enable_http_jails ? {
      true => {
        'http-get-dos' => {
          'enabled'  => true,
          'port'     => 'http,https',
          'filter'   => 'http-get-dos',
          'logpath'  => $http_logpath,
          'maxretry' => 300,  # Higher threshold for GET requests
          'findtime' => '5m',
          'bantime'  => $bantime,
        },
        'http-post-dos' => {
          'enabled'  => true,
          'port'     => 'http,https',
          'filter'   => 'http-post-dos',
          'logpath'  => $http_logpath,
          'maxretry' => 100,  # Lower threshold for POST requests
          'findtime' => '5m',
          'bantime'  => $bantime,
        },
      },
      default => {},
    }

    # Merge all jail configurations
    $all_jails = $base_jails + $ssh_jail + $http_jails

    # Configure fail2ban base class
    class { 'fail2ban':
      package_ensure => $package_ensure,
      service_ensure => $service_ensure,
      service_enable => $service_enable,
      bantime        => $bantime,
      findtime       => $findtime,
      maxretry       => $maxretry,
      destemail      => $destemail,
      sender         => $sender,
      action         => $action,
      jails          => $all_jails,
    }

    # Create custom jails
    $custom_jails.each |String $jail_name, Hash $jail_config| {
      fail2ban::jail { $jail_name:
        * => $jail_config,
      }
    }

    # Create custom filters
    $custom_filters.each |String $filter_name, Hash $filter_config| {
      fail2ban::filter { $filter_name:
        * => $filter_config,
      }
    }

    # Create custom actions
    $custom_actions.each |String $action_name, Hash $action_config| {
      fail2ban::action { $action_name:
        * => $action_config,
      }
    }
  }
}
