# @summary Manages WireGuard VPN server
#
# This profile manages a WireGuard VPN server configuration, including
# interface setup, firewall rules, IP forwarding, and client management.
#
# @param manage_wireguard
#   Whether to manage WireGuard configuration (default: false)
# @param package_name
#   Name of the WireGuard package
# @param interface_name
#   Name of the WireGuard interface (default: wg0)
# @param listen_port
#   UDP port for WireGuard to listen on (default: 51820)
# @param vpn_network
#   VPN network in CIDR notation (e.g., '10.10.10.0/24')
# @param vpn_server_ip
#   Server IP address within the VPN network (e.g., '10.10.10.1')
# @param external_interface
#   External network interface for NAT (e.g., 'eth0')
# @param server_private_key
#   WireGuard server private key (should be encrypted with eyaml)
# @param enable_nat
#   Whether to enable NAT for VPN traffic (default: true)
# @param enable_ip_forward
#   Whether to enable IP forwarding (default: true)
# @param manage_ufw
#   Whether to manage UFW firewall rules for WireGuard (default: true)
# @param peers
#   Hash of WireGuard peer configurations
# @param dns_servers
#   Array of DNS servers to advertise to clients
# @param persistent_keepalive
#   Persistent keepalive interval in seconds (0 to disable)
#
# @example Basic usage
#   include profile::wireguard
#
# @example With custom parameters via Hiera
#   profile::wireguard::manage_wireguard: true
#   profile::wireguard::vpn_network: '10.10.10.0/24'
#   profile::wireguard::vpn_server_ip: '10.10.10.1'
#   profile::wireguard::server_private_key: >
#     ENC[PKCS7,MIIBeQYJKoZIhvcNAQcDoIIBajCCAWYCAQAxggEhMIIBHQIBADAFMAACAQEw...]
#   profile::wireguard::peers:
#     homeserver:
#       public_key: 'client_public_key_here'
#       preshared_key: 'preshared_key_here'
#       allowed_ips: '10.10.10.10/32'
#     laptop:
#       public_key: 'laptop_public_key_here'
#       preshared_key: 'laptop_preshared_key_here'
#       allowed_ips: '10.10.10.11/32'
#
class profile::wireguard (
  Boolean                  $manage_wireguard        = false,
  String[1]                $package_name            = 'wireguard',
  String[1]                $interface_name          = 'wg0',
  Integer[1,65535]         $listen_port             = 51820,
  String[1]                $vpn_network             = '10.10.10.0/24',
  String[1]                $vpn_server_ip           = '10.10.10.1',
  String[1]                $external_interface      = 'eth0',
  Optional[String[1]]      $server_private_key      = undef,
  Boolean                  $enable_nat              = true,
  Boolean                  $enable_ip_forward       = true,
  Boolean                  $manage_ufw              = true,
  Hash                     $peers                   = {},
  Array[String[1]]         $dns_servers             = ['10.10.10.1'],
  Integer[0]               $persistent_keepalive    = 25,
) {
  # Validate that server private key is provided
  if $manage_wireguard and !$server_private_key {
    fail('profile::wireguard: server_private_key is required when manage_wireguard is true')
  }

  if $manage_wireguard {
    # Install WireGuard package
    ensure_packages([$package_name])

    # Create directories for WireGuard configuration
    file { '/etc/wireguard':
      ensure  => directory,
      owner   => 'root',
      group   => 'root',
      mode    => '0700',
      require => Package[$package_name],
    }

    file { '/etc/wireguard/clients':
      ensure  => directory,
      owner   => 'root',
      group   => 'root',
      mode    => '0700',
      require => File['/etc/wireguard'],
    }

    file { '/etc/wireguard/clientconfs':
      ensure  => directory,
      owner   => 'root',
      group   => 'root',
      mode    => '0700',
      require => File['/etc/wireguard'],
    }

    # WireGuard interface configuration
    file { "/etc/wireguard/${interface_name}.conf":
      ensure  => file,
      owner   => 'root',
      group   => 'root',
      mode    => '0600',
      content => template('profile/wireguard/wg0.conf.erb'),
      require => File['/etc/wireguard'],
      notify  => Service["wg-quick@${interface_name}"],
    }

    # Enable IP forwarding via sysctl
    if $enable_ip_forward {
      sysctl { 'net.ipv4.ip_forward':
        ensure => present,
        value  => '1',
      }
    }

    # Manage UFW firewall rules for WireGuard
    if $manage_ufw {
      # Include UFW module (default policy is DROP/deny in /etc/default/ufw)
      # The kogitoapp-ufw module defaults are:
      #   DEFAULT_INPUT_POLICY="DROP"    (deny all incoming by default)
      #   DEFAULT_OUTPUT_POLICY="ACCEPT" (allow all outgoing)
      #   DEFAULT_FORWARD_POLICY="DROP"  (deny forwarding by default)
      include ufw

      # Allow WireGuard port from anywhere (UDP)
      ufw_rule { "allow wireguard port ${listen_port}":
        action       => 'allow',
        to_ports_app => $listen_port,
        proto        => 'udp',
        require      => Class['ufw'],
      }

      # Get SSH port from hiera (may be encrypted)
      # Convert to integer if it's a string from eyaml decryption
      $ssh_port_raw = lookup('profile::ssh_hardening::ssh_port', Optional[Variant[Integer, String]], 'first', undef)
      $ssh_port = $ssh_port_raw ? {
        String  => Integer($ssh_port_raw),
        Integer => $ssh_port_raw,
        default => undef,
      }

      # Allow SSH from anywhere (required for remote access)
      if $ssh_port {
        ufw_rule { "allow SSH port ${ssh_port}":
          action       => 'allow',
          to_ports_app => $ssh_port,
          proto        => 'tcp',
          require      => Class['ufw'],
        }
      }

      # IMPORTANT: UFW processes rules in order!
      # ALLOW rules from VPN must come BEFORE DENY rules from internet
      # Otherwise "deny from anywhere" matches VPN traffic first

      # Allow DNS from VPN network ONLY
      ufw_rule { 'allow DNS from VPN network':
        action       => 'allow',
        from_addr    => $vpn_network,
        to_ports_app => 53,
        proto        => 'any',
        require      => Class['ufw'],
      }

      # Allow HTTP from VPN network (for Pi-hole admin)
      ufw_rule { 'allow HTTP from VPN network':
        action       => 'allow',
        from_addr    => $vpn_network,
        to_ports_app => 80,
        proto        => 'tcp',
        require      => Class['ufw'],
      }

      # Allow HTTPS from VPN network
      ufw_rule { 'allow HTTPS from VPN network':
        action       => 'allow',
        from_addr    => $vpn_network,
        to_ports_app => 443,
        proto        => 'tcp',
        require      => Class['ufw'],
      }

      # Allow Grafana from VPN network
      ufw_rule { 'allow Grafana from VPN network':
        action       => 'allow',
        from_addr    => $vpn_network,
        to_ports_app => 3000,
        proto        => 'tcp',
        require      => Class['ufw'],
      }

      # Allow VictoriaMetrics from VPN network
      ufw_rule { 'allow VictoriaMetrics from VPN network':
        action       => 'allow',
        from_addr    => $vpn_network,
        to_ports_app => 8428,
        proto        => 'tcp',
        require      => Class['ufw'],
      }

      # Allow OTEL Collector from VPN network
      ufw_rule { 'allow OTEL from VPN network':
        action       => 'allow',
        from_addr    => $vpn_network,
        to_ports_app => '4317:4318',
        proto        => 'tcp',
        require      => Class['ufw'],
      }

      ufw_rule { 'allow OTEL Prometheus from VPN network':
        action       => 'allow',
        from_addr    => $vpn_network,
        to_ports_app => 8889,
        proto        => 'tcp',
        require      => Class['ufw'],
      }

      # Allow all Prometheus exporters from VPN network
      ufw_rule { 'allow exporters from VPN network':
        action       => 'allow',
        from_addr    => $vpn_network,
        to_ports_app => '9100:9999',
        proto        => 'tcp',
        require      => Class['ufw'],
      }

      # DENY rules come AFTER ALLOW rules for proper UFW rule ordering
      # CRITICAL: Docker with network_mode: "host" bypasses UFW
      # We must explicitly deny monitoring ports from internet
      # These services bind to monitoring_ip but Docker host networking
      # can still expose them on all interfaces

      # Block HTTP/HTTPS from internet (Pi-hole, monitoring web UIs - VPN only)
      ufw_rule { 'deny HTTP from internet':
        action       => 'deny',
        direction    => 'in',
        to_ports_app => 80,
        proto        => 'tcp',
        require      => Class['ufw'],
      }

      ufw_rule { 'deny HTTPS from internet':
        action       => 'deny',
        direction    => 'in',
        to_ports_app => 443,
        proto        => 'tcp',
        require      => Class['ufw'],
      }

      # Block Grafana from internet (VPN only)
      ufw_rule { 'deny Grafana from internet':
        action       => 'deny',
        direction    => 'in',
        to_ports_app => 3000,
        proto        => 'tcp',
        require      => Class['ufw'],
      }

      # Block VictoriaMetrics from internet (VPN only)
      ufw_rule { 'deny VictoriaMetrics from internet':
        action       => 'deny',
        direction    => 'in',
        to_ports_app => 8428,
        proto        => 'tcp',
        require      => Class['ufw'],
      }

      # Block OTEL Collector from internet (VPN only)
      ufw_rule { 'deny OTEL from internet':
        action       => 'deny',
        direction    => 'in',
        to_ports_app => '4317:4318',
        proto        => 'tcp',
        require      => Class['ufw'],
      }

      ufw_rule { 'deny OTEL Prometheus from internet':
        action       => 'deny',
        direction    => 'in',
        to_ports_app => 8889,
        proto        => 'tcp',
        require      => Class['ufw'],
      }

      # Block all Prometheus exporters from internet (VPN only)
      # Note: This also blocks Authelia (port 9091) from internet
      ufw_rule { 'deny exporters from internet':
        action       => 'deny',
        direction    => 'in',
        to_ports_app => '9100:9999',
        proto        => 'tcp',
        require      => Class['ufw'],
      }

      # Block Redis from internet (used by Authelia for sessions, localhost only)
      ufw_rule { 'deny Redis from internet':
        action       => 'deny',
        direction    => 'in',
        to_ports_app => 6379,
        proto        => 'tcp',
        require      => Class['ufw'],
      }

      # UFW route rule for VPN traffic forwarding
      ufw_route { "allow VPN traffic from ${interface_name} to ${external_interface}":
        action        => 'allow',
        interface_in  => $interface_name,
        interface_out => $external_interface,
        require       => Class['ufw'],
      }

      # UFW route rule for VPN-to-VPN traffic
      ufw_route { "allow VPN-to-VPN traffic on ${interface_name}":
        action        => 'allow',
        interface_in  => $interface_name,
        interface_out => $interface_name,
        require       => Class['ufw'],
      }
    }

    # Clean up orphaned WireGuard interface if service is not running
    # This handles cases where previous runs left the interface in a broken state
    exec { "cleanup-orphaned-${interface_name}":
      command => "/usr/bin/ip link delete ${interface_name}",
      onlyif  => "/usr/bin/ip link show ${interface_name} 2>/dev/null",
      unless  => "/usr/bin/systemctl is-active wg-quick@${interface_name}",
      before  => Service["wg-quick@${interface_name}"],
    }

    # Enable and start WireGuard service
    service { "wg-quick@${interface_name}":
      ensure     => running,
      enable     => true,
      hasrestart => true,
      hasstatus  => true,
      require    => [
        Package[$package_name],
        File["/etc/wireguard/${interface_name}.conf"],
      ],
    }

    # Store peer preshared keys
    $peers.each |$peer_name, $peer_config| {
      if 'preshared_key' in $peer_config {
        file { "/etc/wireguard/clients/${peer_name}.psk":
          ensure  => file,
          owner   => 'root',
          group   => 'root',
          mode    => '0600',
          content => "${peer_config['preshared_key']}\n",
          require => File['/etc/wireguard/clients'],
        }
      }
    }
  }
}
