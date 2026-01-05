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
  contain profile::base
  contain profile::unbound
  contain profile::monitoring
  contain profile::wireguard
  contain profile::pihole_native
}
