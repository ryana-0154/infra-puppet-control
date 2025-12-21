# @summary Manages firewall configuration
#
# This profile manages iptables firewall rules for security hardening.
# It implements a default deny policy with explicit allows for required services.
#
# @param manage_firewall
#   Whether to manage firewall rules
# @param purge_unmanaged
#   Whether to purge unmanaged firewall rules
# @param default_input_policy
#   Default policy for incoming traffic
# @param default_output_policy
#   Default policy for outgoing traffic
# @param default_forward_policy
#   Default policy for forwarded traffic
# @param ssh_port
#   Port for SSH access
# @param ssh_source
#   Source networks allowed SSH access
# @param allow_ping
#   Whether to allow ICMP ping
# @param monitoring_ports
#   Array of monitoring ports to allow
# @param monitoring_from_anywhere
#   Whether to allow monitoring ports from anywhere (not recommended)
# @param wireguard_port
#   Port for WireGuard VPN
# @param wireguard_network
#   WireGuard VPN network CIDR
# @param wireguard_interface
#   WireGuard interface name
# @param allow_wireguard_routing
#   Whether to allow routing between WireGuard interfaces
# @param custom_rules
#   Hash of custom firewall rules
#
# @example Basic usage
#   include profile::firewall
#
# @example Custom SSH port via Hiera
#   profile::firewall::ssh_port: 2222
#
# @example Allow additional ports via Hiera
#   profile::firewall::custom_rules:
#     web_http:
#       port: 80
#       proto: tcp
#       jump: accept
#     web_https:
#       port: 443
#       proto: tcp
#       jump: accept
#
class profile::firewall (
  Boolean                 $manage_firewall         = true,
  Boolean                 $purge_unmanaged         = true,
  Enum['accept', 'drop']  $default_input_policy    = 'drop',
  Enum['accept', 'drop']  $default_output_policy   = 'accept',
  Enum['accept', 'drop']  $default_forward_policy  = 'drop',
  Integer[1,65535]        $ssh_port                = 22,
  Array[String[1]]        $ssh_source              = ['0.0.0.0/0'],
  Boolean                 $allow_ping              = true,
  Array[Integer[1,65535]] $monitoring_ports        = [9090, 9100, 9115],
  Boolean                 $monitoring_from_anywhere = false,
  Optional[Integer[1,65535]] $wireguard_port       = 51820,
  Optional[String[1]]     $wireguard_network       = '10.10.10.0/24',
  Optional[String[1]]     $wireguard_interface     = 'wg0',
  Boolean                 $allow_wireguard_routing = true,
  Hash                    $custom_rules            = {},
) {
  if $manage_firewall {
    # Ensure firewall is installed and running
    include firewall

    # Purge unmanaged rules if enabled
    if $purge_unmanaged {
      resources { 'firewall':
        purge => true,
      }
    }

    # Ensure rules are applied in the correct order
    Firewall {
      before => undef,
    }

    # Set default policies
    firewallchain { 'INPUT:filter:IPv4':
      ensure => present,
      policy => $default_input_policy,
    }

    firewallchain { 'OUTPUT:filter:IPv4':
      ensure => present,
      policy => $default_output_policy,
    }

    firewallchain { 'FORWARD:filter:IPv4':
      ensure => present,
      policy => $default_forward_policy,
    }

    # Essential rules for system operation
    # Allow loopback traffic
    firewall { '001 accept all to lo interface':
      proto   => 'all',
      iniface => 'lo',
      jump    => 'accept',
    }

    firewall { '002 reject local traffic not on loopback interface':
      iniface     => '! lo',
      proto       => 'all',
      destination => '127.0.0.1/8',
      jump        => 'reject',
    }

    # Allow established and related connections
    firewall { '003 accept related established rules':
      proto => 'all',
      state => ['RELATED', 'ESTABLISHED'],
      jump  => 'accept',
    }

    # Allow SSH access
    $ssh_source.each |Integer $index, String $source| {
      firewall { "010 allow ssh from ${source}":
        dport  => $ssh_port,
        proto  => 'tcp',
        source => $source,
        jump   => 'accept',
      }
    }

    # Allow ICMP ping if enabled
    if $allow_ping {
      firewall { '020 allow icmp':
        proto => 'icmp',
        jump  => 'accept',
      }
    }

    # Allow monitoring ports globally (not recommended - use WireGuard access instead)
    if $monitoring_from_anywhere {
      $monitoring_ports.each |Integer $port| {
        firewall { "030 allow monitoring port ${port} from anywhere":
          dport => $port,
          proto => 'tcp',
          jump  => 'accept',
        }
      }
    }

    # WireGuard VPN rules
    if $wireguard_port {
      # Allow WireGuard UDP traffic from anywhere
      firewall { '040 allow wireguard':
        dport => $wireguard_port,
        proto => 'udp',
        jump  => 'accept',
      }
    }

    if $wireguard_network and $wireguard_interface {
      # Allow monitoring services from WireGuard network
      $monitoring_ports.each |Integer $port| {
        firewall { "050 allow monitoring port ${port} from wireguard":
          dport   => $port,
          proto   => 'tcp',
          source  => $wireguard_network,
          iniface => $wireguard_interface,
          jump    => 'accept',
        }
      }

      # Allow common services from WireGuard network
      firewall { '051 allow dns from wireguard':
        dport  => 53,
        proto  => 'udp',
        source => $wireguard_network,
        jump   => 'accept',
      }

      firewall { '052 allow http from wireguard':
        dport  => 80,
        proto  => 'tcp',
        source => $wireguard_network,
        jump   => 'accept',
      }

      firewall { '053 allow https from wireguard':
        dport  => 443,
        proto  => 'tcp',
        source => $wireguard_network,
        jump   => 'accept',
      }

      # Allow WG Portal and Puppet from WireGuard network
      firewall { '054 allow wg-portal from wireguard':
        dport  => 8888,
        proto  => 'tcp',
        source => $wireguard_network,
        jump   => 'accept',
      }

      firewall { '055 allow puppet from wireguard':
        dport  => 8140,
        proto  => 'tcp',
        source => $wireguard_network,
        jump   => 'accept',
      }

      # Allow additional monitoring services from WireGuard
      firewall { '056 allow pihole exporter from wireguard':
        dport   => 9617,
        proto   => 'tcp',
        source  => $wireguard_network,
        iniface => $wireguard_interface,
        jump    => 'accept',
      }

      firewall { '057 allow additional monitoring from wireguard':
        dport   => 9586,
        proto   => 'tcp',
        source  => $wireguard_network,
        iniface => $wireguard_interface,
        jump    => 'accept',
      }

      # Allow Grafana from WireGuard (if enabled)
      firewall { '058 allow grafana from wireguard':
        dport   => 3000,
        proto   => 'tcp',
        source  => $wireguard_network,
        iniface => $wireguard_interface,
        jump    => 'accept',
      }

      # Allow Loki from WireGuard (if enabled)
      firewall { '059 allow loki from wireguard':
        dport   => 3100,
        proto   => 'tcp',
        source  => $wireguard_network,
        iniface => $wireguard_interface,
        jump    => 'accept',
      }

      # Allow routing between WireGuard interfaces if enabled
      if $allow_wireguard_routing {
        firewall { '060 allow wireguard routing':
          chain    => 'FORWARD',
          iniface  => $wireguard_interface,
          outiface => $wireguard_interface,
          jump     => 'accept',
        }
      }
    }

    # Apply custom rules from Hiera
    $custom_rules.each |String $rule_name, Hash $rule_config| {
      $rule_defaults = {
        'proto' => 'tcp',
        'jump'  => 'accept',
      }
      $merged_config = $rule_defaults + $rule_config
      firewall { "100 custom rule ${rule_name}":
        * => $merged_config,
      }
    }

    # Log dropped packets (optional - can be noisy)
    # firewall { '990 log dropped input':
    #   proto     => 'all',
    #   jump      => 'LOG',
    #   log_level => '4',
    #   log_prefix => '[IPTABLES DROPPED INPUT]: ',
    # }

    # Final drop rule (handled by default policy, but explicit for clarity)
    firewall { '999 drop all other input':
      proto => 'all',
      jump  => 'drop',
    }
  }
}
