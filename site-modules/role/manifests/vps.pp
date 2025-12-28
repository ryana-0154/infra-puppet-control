# @summary VPS role for virtual private servers
#
# This role is applied to VPS instances that require
# base configuration, Unbound DNS resolver, monitoring infrastructure,
# WireGuard VPN server, and Pi-hole ad blocking.
#
# @example
#   include role::vps
#
class role::vps {
  include profile::base
  include profile::unbound
  include profile::monitoring
  include profile::wireguard
  include profile::pihole_native
}
