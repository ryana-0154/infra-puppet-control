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
#       port: 80        # Automatically mapped to dport
#       proto: tcp
#       jump: accept
#     web_https:
#       dport: 443      # Direct parameter (preferred)
#       proto: tcp
#       jump: accept
#
class profile::firewall (
  Boolean                 $manage_firewall         = true,
  Boolean                 $purge_unmanaged         = true,
  Enum['accept', 'drop']  $default_input_policy    = 'drop',
  Enum['accept', 'drop']  $default_output_policy   = 'accept',
  Enum['accept', 'drop']  $default_forward_policy  = 'drop',
  Variant[Integer[1,65535], String] $ssh_port      = 22,
  Array[String[1]]        $ssh_source              = ['0.0.0.0/0'],
  Boolean                 $allow_ping              = true,
  Array[Integer[1,65535]] $monitoring_ports        = [9090, 9100, 9115],
  Boolean                 $monitoring_from_anywhere = false,
  Optional[Integer[1,65535]] $wireguard_port       = 51820,
  Optional[String[1]]     $wireguard_network       = '10.10.10.0/24',
  Optional[String[1]]     $wireguard_interface     = 'wg0',
  Boolean                 $allow_wireguard_routing = true,
  Hash[String[1], Hash]   $custom_rules            = {},
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

    # NAT chain for masquerading
    firewallchain { 'POSTROUTING:nat:IPv4':
      ensure => present,
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
      # Allow monitoring services from WireGuard network (to 10.10.10.1)
      $monitoring_ports.each |Integer $port| {
        firewall { "050 allow monitoring port ${port} from wireguard":
          dport       => $port,
          proto       => 'tcp',
          destination => '10.10.10.1',
          iniface     => $wireguard_interface,
          jump        => 'accept',
        }
      }

      # Allow outbound DNS queries (essential for Unbound to resolve external DNS)
      firewall { '045 allow outbound dns udp':
        chain => 'OUTPUT',
        dport => 53,
        proto => 'udp',
        jump  => 'accept',
      }

      firewall { '046 allow outbound dns tcp':
        chain => 'OUTPUT',
        dport => 53,
        proto => 'tcp',
        jump  => 'accept',
      }

      # Allow local communication between PiHole and Unbound
      firewall { '047 allow pihole to unbound':
        dport       => 5353,
        proto       => 'udp',
        source      => '127.0.0.1',
        destination => '127.0.0.1',
        jump        => 'accept',
      }

      # Allow DNS service from WireGuard network (for PiHole/local DNS)
      firewall { '051 allow dns udp from wireguard':
        dport   => 53,
        proto   => 'udp',
        source  => $wireguard_network,
        iniface => $wireguard_interface,
        jump    => 'accept',
      }

      # Allow DNS TCP from WireGuard network (Windows often uses TCP DNS)
      firewall { '052 allow dns tcp from wireguard':
        dport   => 53,
        proto   => 'tcp',
        source  => $wireguard_network,
        iniface => $wireguard_interface,
        jump    => 'accept',
      }

      # Allow Unbound DNS (PiHole backend) from WireGuard network
      firewall { '053 allow unbound from wireguard':
        dport   => 5353,
        proto   => 'udp',
        source  => $wireguard_network,
        iniface => $wireguard_interface,
        jump    => 'accept',
      }

      firewall { '054 allow http from wireguard':
        dport   => 80,
        proto   => 'tcp',
        source  => $wireguard_network,
        iniface => $wireguard_interface,
        jump    => 'accept',
      }

      firewall { '055 allow https from wireguard':
        dport   => 443,
        proto   => 'tcp',
        source  => $wireguard_network,
        iniface => $wireguard_interface,
        jump    => 'accept',
      }

      # Allow WG Portal and Puppet from WireGuard network
      firewall { '056 allow wg-portal from wireguard':
        dport   => 8888,
        proto   => 'tcp',
        source  => $wireguard_network,
        iniface => $wireguard_interface,
        jump    => 'accept',
      }

      firewall { '057 allow puppet from wireguard':
        dport   => 8140,
        proto   => 'tcp',
        source  => $wireguard_network,
        iniface => $wireguard_interface,
        jump    => 'accept',
      }

      # Allow additional monitoring services from WireGuard
      firewall { '058 allow pihole exporter from wireguard':
        dport   => 9617,
        proto   => 'tcp',
        source  => $wireguard_network,
        iniface => $wireguard_interface,
        jump    => 'accept',
      }

      firewall { '059 allow additional monitoring from wireguard':
        dport   => 9586,
        proto   => 'tcp',
        source  => $wireguard_network,
        iniface => $wireguard_interface,
        jump    => 'accept',
      }

      # Allow Grafana from WireGuard (if enabled)
      firewall { '060 allow grafana from wireguard':
        dport   => 3000,
        proto   => 'tcp',
        source  => $wireguard_network,
        iniface => $wireguard_interface,
        jump    => 'accept',
      }

      # Allow Loki from WireGuard (if enabled)
      firewall { '061 allow loki from wireguard':
        dport   => 3100,
        proto   => 'tcp',
        source  => $wireguard_network,
        iniface => $wireguard_interface,
        jump    => 'accept',
      }

      # Allow routing between WireGuard interfaces if enabled
      if $allow_wireguard_routing {
        firewall { '070 allow wireguard routing':
          chain    => 'FORWARD',
          iniface  => $wireguard_interface,
          outiface => $wireguard_interface,
          jump     => 'accept',
        }

        # Allow WireGuard to internet forwarding (essential for DNS/internet access)
        firewall { '071 allow wireguard to internet':
          chain    => 'FORWARD',
          iniface  => $wireguard_interface,
          outiface => '! wg0',  # Any interface except WireGuard
          jump     => 'accept',
        }

        # Allow return traffic from internet to WireGuard clients
        firewall { '072 allow internet to wireguard return':
          chain    => 'FORWARD',
          iniface  => '! wg0',  # Any interface except WireGuard
          outiface => $wireguard_interface,
          state    => ['RELATED', 'ESTABLISHED'],
          jump     => 'accept',
        }

        # Exclude localhost traffic from masquerading
        firewall { '072 exclude localhost from masquerading':
          table       => 'nat',
          chain       => 'POSTROUTING',
          proto       => 'all',
          source      => '127.0.0.0/8',
          destination => '127.0.0.0/8',
          jump        => 'RETURN',
        }

        # NAT masquerading for WireGuard traffic (critical for internet access)
        firewall { '073 masquerade wireguard traffic':
          table    => 'nat',
          chain    => 'POSTROUTING',
          proto    => 'all',
          outiface => '! wg0',  # Any interface except WireGuard
          jump     => 'MASQUERADE',
        }
      }
    }

    # Apply custom rules from Hiera
    $custom_rules.each |String $rule_name, Hash $rule_config| {
      $rule_defaults = {
        'proto' => 'tcp',
        'jump'  => 'accept',
      }

      # Map 'port' parameter to 'dport' for firewall compatibility
      $mapped_config = $rule_config.reduce({}) |Hash $acc, Array $kv| {
        $key = $kv[0]
        $value = $kv[1]
        $mapped_key = $key ? {
          'port' => 'dport',
          default => $key,
        }
        $acc + { $mapped_key => $value }
      }

      $merged_config = $rule_defaults + $mapped_config
      $rule_priority = 100 + $custom_rules.keys.index($rule_name)

      firewall { "${rule_priority} custom rule ${rule_name}":
        * => $merged_config,
      }
    }

    # Log dropped packets for debugging
    # Note: log_level defaults to 4 (warn) and is omitted to prevent drift
    # when iptables-save doesn't persist default values
    firewall { '990 log dropped input':
      proto      => 'all',
      jump       => 'LOG',
      log_prefix => '[IPTABLES DROPPED INPUT]: ',
    }

    firewall { '991 log dropped forward':
      chain      => 'FORWARD',
      proto      => 'all',
      jump       => 'LOG',
      log_prefix => '[IPTABLES DROPPED FORWARD]: ',
    }

    # Final drop rule removed - rely on default policy instead to avoid conflicts
  }
}
