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
#
# @example
#   include profile::base
#
class profile::base (
  Boolean $manage_ntp      = true,
  Boolean $manage_firewall = true,
  Boolean $manage_logrotate = true,
) {
  # NTP configuration
  if $manage_ntp {
    include ntp
  }

  # Firewall configuration
  if $manage_firewall {
    include profile::firewall
  }

  if $manage_logrotate {
    include logrotate
  }

  # Basic package management
  ensure_packages(['vim', 'curl', 'wget'], { ensure => 'present' })
}
