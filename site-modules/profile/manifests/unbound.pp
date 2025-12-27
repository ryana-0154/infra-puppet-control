# @summary Manages Unbound DNS resolver
#
# This profile manages the Unbound DNS resolver, typically used as an
# upstream recursive DNS server for Pi-hole. Unbound provides DNSSEC
# validation and caching for improved DNS security and performance.
#
# @param manage_unbound
#   Whether to manage Unbound configuration (default: false)
# @param package_name
#   Name of the unbound package
# @param service_name
#   Name of the unbound service
# @param config_dir
#   Directory where Unbound stores its configuration
# @param config_file
#   Main Unbound configuration file path
# @param log_dir
#   Directory for Unbound log files
# @param listen_interface
#   IP address to listen on (default: 127.0.0.1)
# @param listen_port
#   Port to listen on (default: 5353, non-standard to avoid conflicts with Pi-hole)
# @param num_threads
#   Number of threads to use
# @param access_control
#   Hash of access control rules (CIDR => allow/refuse/deny)
# @param enable_ipv6
#   Whether to enable IPv6 support
# @param cache_min_ttl
#   Minimum cache TTL in seconds
# @param cache_max_ttl
#   Maximum cache TTL in seconds
# @param enable_prefetch
#   Whether to enable prefetching of cache elements before expiry
# @param enable_dnssec
#   Whether to enable DNSSEC validation
# @param private_addresses
#   Array of private address ranges to hide
# @param enable_logging
#   Whether to enable query/reply logging
# @param verbosity
#   Logging verbosity level (0-5)
#
# @example Basic usage
#   include profile::unbound
#
# @example With custom parameters via Hiera
#   profile::unbound::manage_unbound: true
#   profile::unbound::listen_port: 5353
#   profile::unbound::access_control:
#     '127.0.0.1/32': 'allow'
#     '10.10.10.0/24': 'allow'
#     '0.0.0.0/0': 'refuse'
#
class profile::unbound (
  Boolean                  $manage_unbound      = false,
  String[1]                $package_name        = 'unbound',
  String[1]                $service_name        = 'unbound',
  Stdlib::Absolutepath     $config_dir          = '/etc/unbound',
  Stdlib::Absolutepath     $config_file         = '/etc/unbound/unbound.conf',
  Stdlib::Absolutepath     $log_dir             = '/var/log/unbound',
  String[1]                $listen_interface    = '127.0.0.1',
  Integer[1,65535]         $listen_port         = 5353,
  Integer[1,128]           $num_threads         = 4,
  Hash[String[1],String[1]] $access_control     = {
    '0.0.0.0/0'     => 'refuse',
    '127.0.0.1/32'  => 'allow',
    '10.10.10.0/24' => 'allow',
  },
  Boolean                  $enable_ipv6         = false,
  Integer[0]               $cache_min_ttl       = 1800,
  Integer[0]               $cache_max_ttl       = 14400,
  Boolean                  $enable_prefetch     = true,
  Boolean                  $enable_dnssec       = true,
  Array[String[1]]         $private_addresses   = ['10.0.0.0/8'],
  Boolean                  $enable_logging      = true,
  Integer[0,5]             $verbosity           = 1,
) {
  if $manage_unbound {
    # Install Unbound package
    ensure_packages([$package_name])

    # Ensure config directory exists
    file { $config_dir:
      ensure  => directory,
      owner   => 'root',
      group   => 'root',
      mode    => '0755',
      require => Package[$package_name],
    }

    # Ensure config.d directory exists
    file { "${config_dir}/unbound.conf.d":
      ensure  => directory,
      owner   => 'root',
      group   => 'root',
      mode    => '0755',
      require => File[$config_dir],
    }

    # Ensure log directory exists
    file { $log_dir:
      ensure  => directory,
      owner   => 'unbound',
      group   => 'unbound',
      mode    => '0755',
      require => Package[$package_name],
    }

    # Main configuration file
    file { $config_file:
      ensure  => file,
      owner   => 'root',
      group   => 'root',
      mode    => '0644',
      content => template('profile/unbound/unbound.conf.erb'),
      require => File[$config_dir],
      notify  => Service[$service_name],
    }

    # Pi-hole integration config
    file { "${config_dir}/unbound.conf.d/pi-hole.conf":
      ensure  => file,
      owner   => 'root',
      group   => 'root',
      mode    => '0644',
      content => template('profile/unbound/pi-hole.conf.erb'),
      require => File["${config_dir}/unbound.conf.d"],
      notify  => Service[$service_name],
    }

    # Remote control config
    file { "${config_dir}/unbound.conf.d/remote-control.conf":
      ensure  => file,
      owner   => 'root',
      group   => 'root',
      mode    => '0644',
      content => template('profile/unbound/remote-control.conf.erb'),
      require => File["${config_dir}/unbound.conf.d"],
      notify  => Service[$service_name],
    }

    # DNSSEC trust anchor config
    file { "${config_dir}/unbound.conf.d/root-auto-trust-anchor-file.conf":
      ensure  => file,
      owner   => 'root',
      group   => 'root',
      mode    => '0644',
      content => template('profile/unbound/root-auto-trust-anchor-file.conf.erb'),
      require => File["${config_dir}/unbound.conf.d"],
      notify  => Service[$service_name],
    }

    # Ensure the service is running and enabled
    service { $service_name:
      ensure     => running,
      enable     => true,
      hasrestart => true,
      hasstatus  => true,
      require    => [
        Package[$package_name],
        File[$config_file],
      ],
    }
  }
}
