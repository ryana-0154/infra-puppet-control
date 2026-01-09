# @summary NTP time synchronization profile
#
# This profile wraps the puppetlabs-ntp module with Foreman ENC-first
# parameter resolution. It can be independently assigned via Foreman.
#
# @param manage_ntp
#   Whether to manage NTP configuration
# @param servers
#   Array of NTP servers to use
# @param restrict
#   Array of restrict directives for ntpd
# @param service_enable
#   Whether to enable the NTP service at boot
# @param service_ensure
#   Desired state of the NTP service
#
# @example Basic usage
#   include profile::ntp
#
# @example With custom servers via Foreman parameter
#   # Set ntp_servers parameter in Foreman hostgroup
#
class profile::ntp (
  Boolean        $manage_ntp     = true,
  Array[String]  $servers        = ['0.pool.ntp.org', '1.pool.ntp.org', '2.pool.ntp.org', '3.pool.ntp.org'],
  Array[String]  $restrict       = [
    'default kod nomodify notrap nopeer noquery',
    '-6 default kod nomodify notrap nopeer noquery',
    '127.0.0.1',
    '-6 ::1',
  ],
  Boolean        $service_enable = true,
  Enum['running', 'stopped'] $service_ensure = 'running',
) {
  # Foreman ENC -> Hiera -> Default resolution
  $_manage_ntp_enc = getvar('ntp_manage')
  $_manage_ntp = $_manage_ntp_enc ? {
    undef   => $manage_ntp,
    default => $_manage_ntp_enc,
  }

  $_servers_enc = getvar('ntp_servers')
  $_servers = $_servers_enc ? {
    undef   => $servers,
    default => $_servers_enc,
  }

  $_restrict_enc = getvar('ntp_restrict')
  $_restrict = $_restrict_enc ? {
    undef   => $restrict,
    default => $_restrict_enc,
  }

  $_service_enable_enc = getvar('ntp_service_enable')
  $_service_enable = $_service_enable_enc ? {
    undef   => $service_enable,
    default => $_service_enable_enc,
  }

  $_service_ensure_enc = getvar('ntp_service_ensure')
  $_service_ensure = $_service_ensure_enc ? {
    undef   => $service_ensure,
    default => $_service_ensure_enc,
  }

  if $_manage_ntp {
    class { 'ntp':
      servers        => $_servers,
      restrict       => $_restrict,
      service_enable => $_service_enable,
      service_ensure => $_service_ensure,
    }
  }
}
