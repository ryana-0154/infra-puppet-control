# @summary Minimal base profile for all nodes
#
# This profile contains only the truly universal baseline configuration
# that every node requires. All other functionality (NTP, firewall,
# fail2ban, etc.) should be assigned as separate profiles via Foreman.
#
# Includes:
# - DNS resolver configuration (required for Puppet to work)
# - Puppet agent configuration (required for Puppet to work)
# - Basic utility packages
#
# @example
#   include profile::base
#
class profile::base {
  # DNS configuration - required for internal DNS resolution
  contain profile::dns

  # Puppet agent configuration - required for Puppet Server connectivity
  contain profile::puppet_agent

  # Basic utility packages available on all nodes
  ensure_packages(['vim', 'curl', 'wget'], { ensure => 'present' })
}
