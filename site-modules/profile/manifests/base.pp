# @summary Base profile for all nodes
#
# This profile contains the baseline configuration that should be
# applied to every node. It includes essential services and security settings.
#
# @param manage_ntp
#   Whether to manage NTP configuration
# @param manage_firewall
#   Whether to manage firewall configuration
# @param manage_logrotate
#   Whether to manage logrotate configuration
# @param manage_otel_collector
#   Whether to manage OpenTelemetry Collector
# @param manage_fail2ban
#   Whether to manage fail2ban intrusion prevention
# @param manage_unattended_upgrades
#   Whether to manage automatic security updates
# @param manage_ssh_hardening
#   Whether to manage SSH server security configuration
#
# @example
#   include profile::base
#
class profile::base (
  Boolean $manage_ntp                 = true,
  Boolean $manage_firewall            = true,
  Boolean $manage_logrotate           = true,
  Boolean $manage_otel_collector      = false,
  Boolean $manage_fail2ban            = false,
  Boolean $manage_unattended_upgrades = false,
  Boolean $manage_ssh_hardening       = false,
) {
  # NTP configuration
  if $manage_ntp {
    include ntp
  }

  # Firewall configuration
  if $manage_firewall {
    include profile::firewall
  } else {
    # When firewall is disabled, purge old iptables rules created by puppetlabs-firewall module
    # This prevents conflicts with UFW
    resources { 'firewall':
      purge => true,
    }
  }

  if $manage_logrotate {
    include logrotate
  }

  # OpenTelemetry Collector configuration
  if $manage_otel_collector {
    include profile::otel_collector
  }

  # Fail2ban intrusion prevention
  if $manage_fail2ban {
    include profile::fail2ban
  }

  # Unattended upgrades for automatic security updates
  if $manage_unattended_upgrades {
    include profile::unattended_upgrades
  }

  # SSH server hardening
  if $manage_ssh_hardening {
    include profile::ssh_hardening
  }

  # Basic package management
  ensure_packages(['vim', 'curl', 'wget'], { ensure => 'present' })
}
