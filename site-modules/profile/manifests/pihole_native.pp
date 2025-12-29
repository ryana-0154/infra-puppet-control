# @summary Manages native Pi-hole installation and configuration
#
# This profile manages a native Pi-hole installation (not Docker-based) for
# network-wide ad blocking and DNS management. It integrates with WireGuard
# VPN and Unbound recursive DNS resolver.
#
# @param manage_pihole
#   Whether to manage Pi-hole installation (default: false)
# @param install_pihole
#   Whether to manage Pi-hole installation (default: true)
# @param pihole_interface
#   Network interface Pi-hole should listen on (e.g., 'wg0' for VPN)
# @param pihole_ipv4_address
#   IPv4 address for Pi-hole (e.g., '10.10.10.1/24')
# @param pihole_webpassword
#   Pi-hole admin web interface password (should be encrypted with eyaml)
# @param upstream_dns_servers
#   Array of upstream DNS servers (default: ['127.0.0.1#5353'] for Unbound)
# @param query_logging
#   Whether to enable DNS query logging (default: true)
# @param install_web_interface
#   Whether to install the web admin interface (default: true)
# @param install_web_server
#   Whether to install lighttpd web server (default: true)
# @param pihole_dns_port
#   Port for Pi-hole DNS service (default: 53)
# @param blocking_enabled
#   Whether ad blocking is enabled (default: true)
# @param local_dns_records
#   Hash of local DNS records to configure (hostname => IP)
# @param dnsmasq_listening
#   DNSMasq listening mode (single, all, local, bind)
#
# @example Basic usage
#   include profile::pihole_native
#
# @example With custom parameters via Hiera
#   profile::pihole_native::manage_pihole: true
#   profile::pihole_native::pihole_interface: 'wg0'
#   profile::pihole_native::pihole_ipv4_address: '10.10.10.1/24'
#   profile::pihole_native::pihole_webpassword: >
#     ENC[PKCS7,MIIBeQYJKoZIhvcNAQcDoIIBajCCAWYCAQAxggEhMIIBHQIBADAFMAACAQEw...]
#   profile::pihole_native::upstream_dns_servers:
#     - '127.0.0.1#5353'
#   profile::pihole_native::local_dns_records:
#     'emby.home.server': '192.168.1.10'
#     'emby.travel.server': '10.10.10.10'
#
class profile::pihole_native (
  Boolean                  $manage_pihole           = false,
  Boolean                  $install_pihole          = true,
  String[1]                $pihole_interface        = 'wg0',
  String[1]                $pihole_ipv4_address     = '10.10.10.1/24',
  Optional[String[1]]      $pihole_webpassword      = undef,
  Array[String[1]]         $upstream_dns_servers    = ['127.0.0.1#5353'],
  Boolean                  $query_logging           = true,
  Boolean                  $install_web_interface   = true,
  Boolean                  $install_web_server      = true,
  Integer[1,65535]         $pihole_dns_port         = 53,
  Boolean                  $blocking_enabled        = true,
  Hash[String[1],String[1]] $local_dns_records      = {},
  Enum['single','all','local','bind'] $dnsmasq_listening = 'bind',
) {
  if $manage_pihole {
    # Ensure curl is installed for Pi-hole installer
    ensure_packages(['curl'])

    # Create Pi-hole configuration directory
    # Note: Pi-hole expects this directory to be owned by pihole:pihole
    # Setting to root:root causes a race condition where Pi-hole FTL changes it back
    file { '/etc/pihole':
      ensure  => directory,
      owner   => 'pihole',
      group   => 'pihole',
      mode    => '0755',
      require => Package['curl'],
    }

    # Create setupVars.conf for automated installation
    # Note: Pi-hole FTL manages this file and expects pihole:pihole ownership
    file { '/etc/pihole/setupVars.conf':
      ensure  => file,
      owner   => 'pihole',
      group   => 'pihole',
      mode    => '0640',
      content => template('profile/pihole_native/setupVars.conf.erb'),
      require => File['/etc/pihole'],
    }

    # Install Pi-hole using official installer
    # The 'creates' parameter makes this idempotent - only runs if pihole binary doesn't exist
    if $install_pihole {
      exec { 'install-pihole':
        command => 'curl -sSL https://install.pi-hole.net | bash /dev/stdin --unattended',
        path    => ['/usr/bin', '/usr/local/bin', '/bin'],
        creates => '/usr/local/bin/pihole',
        timeout => 600,
        require => [
          File['/etc/pihole/setupVars.conf'],
          Package['curl'],
        ],
      }

      # Set web password after installation
      # Only runs if pihole is installed AND password hasn't been set by Puppet yet
      if $pihole_webpassword {
        # Write password to temp file to avoid shell injection
        file { '/tmp/pihole-password.tmp':
          ensure  => file,
          owner   => 'root',
          group   => 'root',
          mode    => '0600',
          content => $pihole_webpassword,
        }

        exec { 'set-pihole-password':
          command => 'pihole -a -p < /tmp/pihole-password.tmp && rm -f /tmp/pihole-password.tmp',
          path    => ['/usr/local/bin', '/usr/bin', '/bin'],
          unless  => 'test -f /etc/pihole/.password_set',
          require => [Exec['install-pihole'], File['/tmp/pihole-password.tmp']],
        }

        # Create flag file to prevent password reset on every Puppet run
        # Note: Use pihole:pihole ownership to match Pi-hole's expectations
        file { '/etc/pihole/.password_set':
          ensure  => file,
          owner   => 'pihole',
          group   => 'pihole',
          mode    => '0640',
          content => "Password set by Puppet at ${facts['timestamp']}\n",
          require => Exec['set-pihole-password'],
        }
      }
    }

    # Configure local DNS records in custom.list
    # Note: Pi-hole FTL manages this file and expects pihole:pihole ownership
    if !empty($local_dns_records) {
      file { '/etc/pihole/custom.list':
        ensure  => file,
        owner   => 'pihole',
        group   => 'pihole',
        mode    => '0640',
        content => template('profile/pihole_native/custom.list.erb'),
        require => File['/etc/pihole'],
        notify  => Exec['pihole-reload-dns'],
      }
    }

    # Configure pihole-FTL to bind web server only to VPN IP (not all interfaces)
    # This prevents the Pi-hole web interface from being exposed to the internet
    # Note: Pi-hole FTL manages this file and expects pihole:pihole ownership
    file { '/etc/pihole/pihole-FTL.conf':
      ensure  => file,
      owner   => 'pihole',
      group   => 'pihole',
      mode    => '0640',
      content => template('profile/pihole_native/pihole-FTL.conf.erb'),
      require => File['/etc/pihole'],
      notify  => Service['pihole-FTL'],
    }

    # Configure Pi-hole DNS settings
    file { '/etc/dnsmasq.d/01-pihole.conf':
      ensure  => file,
      owner   => 'root',
      group   => 'root',
      mode    => '0640',
      content => template('profile/pihole_native/01-pihole.conf.erb'),
      notify  => Exec['pihole-reload-dns'],
    }

    # Reload Pi-hole DNS when configuration changes
    exec { 'pihole-reload-dns':
      command     => 'pihole restartdns reload-lists',
      path        => ['/usr/local/bin', '/usr/bin', '/bin'],
      refreshonly => true,
    }

    # Ensure FTL service is running
    service { 'pihole-FTL':
      ensure  => running,
      enable  => true,
      require => [
        File['/etc/pihole/setupVars.conf'],
        File['/etc/pihole/pihole-FTL.conf'],
      ],
    }
  }
}
