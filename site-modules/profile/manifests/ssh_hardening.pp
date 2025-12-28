# @summary Manages SSH server hardening
#
# This profile configures SSH server security settings including:
# - Disabling password authentication (key-based auth only)
# - Changing SSH port from default 22
# - Disabling root login
# - Other SSH hardening options
#
# @param manage_ssh
#   Whether to manage SSH server configuration (default: false)
# @param ssh_port
#   SSH port number (should match firewall configuration)
# @param permit_root_login
#   Whether to allow root login (default: 'no')
# @param password_authentication
#   Whether to allow password authentication (default: 'no' - keys only)
# @param pubkey_authentication
#   Whether to allow public key authentication (default: 'yes')
# @param challenge_response_authentication
#   Whether to allow challenge-response authentication (default: 'no')
# @param gssapi_authentication
#   Whether to allow GSSAPI authentication (default: 'no')
# @param x11_forwarding
#   Whether to allow X11 forwarding (default: 'no')
# @param print_motd
#   Whether to print MOTD (default: 'no')
# @param accept_env
#   Environment variables to accept from client
# @param client_alive_interval
#   Interval in seconds for keepalive messages (0 = disabled)
# @param client_alive_count_max
#   Maximum number of keepalive messages before disconnecting
# @param max_auth_tries
#   Maximum number of authentication attempts (default: 3)
# @param max_sessions
#   Maximum number of sessions per connection (default: 10)
# @param protocol
#   SSH protocol version (default: 2)
# @param ciphers
#   Allowed ciphers (empty = use SSH defaults)
# @param macs
#   Allowed MACs (empty = use SSH defaults)
# @param kex_algorithms
#   Allowed key exchange algorithms (empty = use SSH defaults)
# @param log_level
#   SSH daemon log level (default: 'INFO')
# @param use_dns
#   Whether to use DNS lookups (default: 'no' for performance)
#
# @example Basic usage
#   include profile::ssh_hardening
#
# @example With custom parameters via Hiera
#   profile::ssh_hardening::manage_ssh: true
#   profile::ssh_hardening::ssh_port: 2222
#   profile::ssh_hardening::permit_root_login: 'no'
#   profile::ssh_hardening::password_authentication: 'no'
#
class profile::ssh_hardening (
  Boolean                  $manage_ssh                         = false,
  Variant[Integer[1,65535], String] $ssh_port                  = 22,
  Enum['yes','no','prohibit-password','forced-commands-only'] $permit_root_login = 'prohibit-password',
  Enum['yes','no']         $password_authentication            = 'no',
  Enum['yes','no']         $pubkey_authentication              = 'yes',
  Enum['yes','no']         $challenge_response_authentication  = 'no',
  Enum['yes','no']         $gssapi_authentication              = 'no',
  Enum['yes','no']         $x11_forwarding                     = 'no',
  Enum['yes','no']         $print_motd                         = 'no',
  Array[String[1]]         $accept_env                         = ['LANG', 'LC_*'],
  Integer[0]               $client_alive_interval              = 300,
  Integer[0]               $client_alive_count_max             = 3,
  Integer[1]               $max_auth_tries                     = 3,
  Integer[1]               $max_sessions                       = 10,
  Integer[2]               $protocol                           = 2,
  Array[String[1]]         $ciphers                            = [],
  Array[String[1]]         $macs                               = [],
  Array[String[1]]         $kex_algorithms                     = [],
  Enum['QUIET','FATAL','ERROR','INFO','VERBOSE','DEBUG','DEBUG1','DEBUG2','DEBUG3'] $log_level = 'INFO',
  Enum['yes','no']         $use_dns                            = 'no',
) {
  if $manage_ssh {
    # Build server options hash
    $base_server_options = {
      'Port'                            => $ssh_port,
      'Protocol'                        => $protocol,
      'PermitRootLogin'                 => $permit_root_login,
      'PubkeyAuthentication'            => $pubkey_authentication,
      'PasswordAuthentication'          => $password_authentication,
      'ChallengeResponseAuthentication' => $challenge_response_authentication,
      'GSSAPIAuthentication'            => $gssapi_authentication,
      'X11Forwarding'                   => $x11_forwarding,
      'PrintMotd'                       => $print_motd,
      'AcceptEnv'                       => $accept_env.join(' '),
      'ClientAliveInterval'             => $client_alive_interval,
      'ClientAliveCountMax'             => $client_alive_count_max,
      'MaxAuthTries'                    => $max_auth_tries,
      'MaxSessions'                     => $max_sessions,
      'LogLevel'                        => $log_level,
      'UseDNS'                          => $use_dns,
    }

    # Add optional cryptographic settings
    $cipher_options = !empty($ciphers) ? {
      true  => { 'Ciphers' => $ciphers.join(',') },
      false => {},
    }

    $mac_options = !empty($macs) ? {
      true  => { 'MACs' => $macs.join(',') },
      false => {},
    }

    $kex_options = !empty($kex_algorithms) ? {
      true  => { 'KexAlgorithms' => $kex_algorithms.join(',') },
      false => {},
    }

    # Merge all options
    $server_options = $base_server_options + $cipher_options + $mac_options + $kex_options

    # Use saz/ssh module for SSH server configuration
    class { 'ssh':
      storeconfigs_enabled => false,
      server_options       => $server_options,
    }
  }
}
