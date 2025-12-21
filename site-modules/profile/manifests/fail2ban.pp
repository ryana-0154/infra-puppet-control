# @summary Manages fail2ban intrusion prevention system
#
# This profile manages fail2ban for protecting services from brute-force attacks.
# It provides default protection for SSH and optionally HTTP/HTTPS, with support
# for custom jails, filters, and actions via Hiera.
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
#   SSH port to monitor (auto-detected from firewall profile if not set)
# @param http_logpath
#   Array of HTTP/HTTPS log file paths to monitor
# @param custom_jails
#   Hash of custom jail configurations from Hiera
# @param custom_filters
#   Hash of custom filter definitions from Hiera
# @param custom_actions
#   Hash of custom action definitions from Hiera
#
# @example Basic usage
#   include profile::fail2ban
#
# @example Enable via profile::base with Hiera
#   profile::base::manage_fail2ban: true
#
# @example Custom jail configuration via Hiera
#   profile::fail2ban::custom_jails:
#     nginx-limit-req:
#       jail_name: 'nginx-limit-req'
#       jail_content:
#         nginx-limit-req:
#           enabled: true
#           port: 'http,https'
#           logpath: '/var/log/nginx/error.log'
#           maxretry: 2
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
  Optional[Variant[Integer[1, 65535], String[1]]] $ssh_port = undef,
  Array[String[1]] $http_logpath             = ['/var/log/nginx/access.log', '/var/log/apache2/access.log'],
  Hash $custom_jails                         = {},
  Hash $custom_filters                       = {},
  Hash $custom_actions                       = {},
) {
  if $manage_fail2ban {
    # Auto-detect SSH port from firewall profile via Hiera lookup
    # Falls back to 22 if not configured in firewall profile
    $real_ssh_port = $ssh_port ? {
      undef   => lookup('profile::firewall::ssh_port', Variant[Integer[1, 65535], String[1]], 'first', 22),
      default => $ssh_port,
    }

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
          'port'     => $real_ssh_port,
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

    # Create custom jails from Hiera
    $custom_jails.each |String $jail_name, Hash $jail_config| {
      fail2ban::jail { $jail_name:
        * => $jail_config,
      }
    }

    # Create custom filters from Hiera
    $custom_filters.each |String $filter_name, Hash $filter_config| {
      fail2ban::filter { $filter_name:
        * => $filter_config,
      }
    }

    # Create custom actions from Hiera
    $custom_actions.each |String $action_name, Hash $action_config| {
      fail2ban::action { $action_name:
        * => $action_config,
      }
    }
  }
}
