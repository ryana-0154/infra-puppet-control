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
#
# @example
#   include profile::base
#
class profile::base (
  Boolean $manage_ntp           = lookup('manage_ntp', Boolean, 'first', true),
  Boolean $manage_firewall      = lookup('manage_firewall', Boolean, 'first', true),
  Boolean $manage_logrotate     = lookup('manage_logrotate', Boolean, 'first', true),
  Boolean $manage_otel_collector = lookup('manage_otel_collector', Boolean, 'first', false),
) {
  # NTP configuration
  if $manage_ntp {
    include ntp
  }

  # Firewall configuration
  if $manage_firewall {
    include firewall
  }

  if $manage_logrotate {
    include logrotate
  }

  # OpenTelemetry Collector configuration
  if $manage_otel_collector {
    include profile::otel_collector
  }

  # Basic package management
  ensure_packages(['vim', 'curl', 'wget'], { ensure => 'present' })
}
