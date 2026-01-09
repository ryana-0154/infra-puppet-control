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
#   WireGuard server private key (should come from Vault or eyaml)
# @param enable_nat
#   Whether to enable NAT for VPN traffic (default: true)
# @param enable_ip_forward
#   Whether to enable IP forwarding (default: true)
# @param manage_ufw
#   Whether to manage UFW firewall rules for WireGuard (default: true)
# @param ssh_port
#   SSH port for firewall rules (shared parameter from Foreman)
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
  Integer[1,65535]         $ssh_port                = 22,
  Hash[String[1], Hash]    $peers                   = {},
  Array[String[1]]         $dns_servers             = ['10.10.10.1'],
  Integer[0]               $persistent_keepalive    = 25,
) {
  # Foreman ENC -> Hiera (via APL) -> Default resolution
  $_manage_wireguard_enc = getvar('wireguard_manage')
  $_manage_wireguard = $_manage_wireguard_enc ? {
    undef   => $manage_wireguard,
    default => $_manage_wireguard_enc,
  }

  $_listen_port_enc = getvar('wireguard_listen_port')
  $_listen_port = $_listen_port_enc ? {
    undef   => $listen_port,
    default => $_listen_port_enc,
  }

  $_vpn_network_enc = getvar('vpn_network')
  $_vpn_network = $_vpn_network_enc ? {
    undef   => $vpn_network,
    default => $_vpn_network_enc,
  }

  $_vpn_server_ip_enc = getvar('wireguard_server_ip')
  $_vpn_server_ip = $_vpn_server_ip_enc ? {
    undef   => $vpn_server_ip,
    default => $_vpn_server_ip_enc,
  }

  $_interface_name_enc = getvar('wireguard_interface')
  $_interface_name = $_interface_name_enc ? {
    undef   => $interface_name,
    default => $_interface_name_enc,
  }

  $_external_interface_enc = getvar('wireguard_external_interface')
  $_external_interface = $_external_interface_enc ? {
    undef   => $external_interface,
    default => $_external_interface_enc,
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

  # Validate that server private key is provided
  if $_manage_wireguard and !$server_private_key {
    fail('profile::wireguard: server_private_key is required when manage_wireguard is true')
  }

  if $_manage_wireguard {
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
    file { "/etc/wireguard/${_interface_name}.conf":
      ensure  => file,
      owner   => 'root',
      group   => 'root',
      mode    => '0600',
      content => template('profile/wireguard/wg0.conf.erb'),
      require => File['/etc/wireguard'],
      notify  => Service["wg-quick@${_interface_name}"],
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
      include ufw

      # Allow WireGuard port from anywhere (UDP)
      ufw_rule { "allow wireguard port ${_listen_port}":
        action       => 'allow',
        to_ports_app => $_listen_port,
        proto        => 'udp',
        require      => Class['ufw'],
      }

      # Allow SSH from anywhere (required for remote access)
      ufw_rule { "allow SSH port ${_ssh_port}":
        action       => 'allow',
        to_ports_app => $_ssh_port,
        proto        => 'tcp',
        require      => Class['ufw'],
      }

      # IMPORTANT: UFW processes rules in order!
      # ALLOW rules from VPN must come BEFORE DENY rules from internet

      # Allow DNS from VPN network ONLY
      ufw_rule { 'allow DNS from VPN network':
        action       => 'allow',
        from_addr    => $_vpn_network,
        to_ports_app => 53,
        proto        => 'any',
        require      => Class['ufw'],
      }

      # Allow HTTP from VPN network (for Pi-hole admin)
      ufw_rule { 'allow HTTP from VPN network':
        action       => 'allow',
        from_addr    => $_vpn_network,
        to_ports_app => 80,
        proto        => 'tcp',
        require      => Class['ufw'],
      }

      # Allow HTTPS from VPN network
      ufw_rule { 'allow HTTPS from VPN network':
        action       => 'allow',
        from_addr    => $_vpn_network,
        to_ports_app => 443,
        proto        => 'tcp',
        require      => Class['ufw'],
      }

      # Allow Grafana from VPN network
      ufw_rule { 'allow Grafana from VPN network':
        action       => 'allow',
        from_addr    => $_vpn_network,
        to_ports_app => 3000,
        proto        => 'tcp',
        require      => Class['ufw'],
      }

      # Allow VictoriaMetrics from VPN network
      ufw_rule { 'allow VictoriaMetrics from VPN network':
        action       => 'allow',
        from_addr    => $_vpn_network,
        to_ports_app => 8428,
        proto        => 'tcp',
        require      => Class['ufw'],
      }

      # Allow OTEL Collector from VPN network
      ufw_rule { 'allow OTEL from VPN network':
        action       => 'allow',
        from_addr    => $_vpn_network,
        to_ports_app => '4317:4318',
        proto        => 'tcp',
        require      => Class['ufw'],
      }

      ufw_rule { 'allow OTEL Prometheus from VPN network':
        action       => 'allow',
        from_addr    => $_vpn_network,
        to_ports_app => 8889,
        proto        => 'tcp',
        require      => Class['ufw'],
      }

      # Allow Prometheus from VPN network
      ufw_rule { 'allow Prometheus from VPN network':
        action       => 'allow',
        from_addr    => $_vpn_network,
        to_ports_app => 9090,
        proto        => 'tcp',
        require      => Class['ufw'],
      }

      # Allow Authelia from VPN network
      ufw_rule { 'allow Authelia from VPN network':
        action       => 'allow',
        from_addr    => $_vpn_network,
        to_ports_app => 9091,
        proto        => 'tcp',
        require      => Class['ufw'],
      }

      # Allow all Prometheus exporters from VPN network
      ufw_rule { 'allow exporters from VPN network':
        action       => 'allow',
        from_addr    => $_vpn_network,
        to_ports_app => '9100:9999',
        proto        => 'tcp',
        require      => Class['ufw'],
      }

      # DENY rules come AFTER ALLOW rules for proper UFW rule ordering
      # CRITICAL: Docker with network_mode: "host" bypasses UFW
      # We must explicitly deny monitoring ports from internet

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

      # Block Prometheus from internet (VPN only)
      ufw_rule { 'deny Prometheus from internet':
        action       => 'deny',
        direction    => 'in',
        to_ports_app => 9090,
        proto        => 'tcp',
        require      => Class['ufw'],
      }

      # Block Authelia from internet (VPN only)
      ufw_rule { 'deny Authelia from internet':
        action       => 'deny',
        direction    => 'in',
        to_ports_app => 9091,
        proto        => 'tcp',
        require      => Class['ufw'],
      }

      # Block all Prometheus exporters from internet (VPN only)
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
      ufw_route { "allow VPN traffic from ${_interface_name} to ${_external_interface}":
        action        => 'allow',
        interface_in  => $_interface_name,
        interface_out => $_external_interface,
        require       => Class['ufw'],
      }

      # UFW route rule for VPN-to-VPN traffic
      ufw_route { "allow VPN-to-VPN traffic on ${_interface_name}":
        action        => 'allow',
        interface_in  => $_interface_name,
        interface_out => $_interface_name,
        require       => Class['ufw'],
      }
    }

    # Clean up orphaned WireGuard interface if service is not running
    exec { "cleanup-orphaned-${_interface_name}":
      command => "/usr/bin/ip link delete ${_interface_name}",
      onlyif  => "/usr/bin/ip link show ${_interface_name} 2>/dev/null",
      unless  => "/usr/bin/systemctl is-active wg-quick@${_interface_name}",
      before  => Service["wg-quick@${_interface_name}"],
    }

    # Enable and start WireGuard service
    service { "wg-quick@${_interface_name}":
      ensure     => running,
      enable     => true,
      hasrestart => true,
      hasstatus  => true,
      require    => [
        Package[$package_name],
        File["/etc/wireguard/${_interface_name}.conf"],
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
