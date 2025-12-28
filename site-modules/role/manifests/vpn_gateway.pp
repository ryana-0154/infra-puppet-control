# @summary VPN Gateway role
#
# Role for VPN gateway servers with WireGuard, Pi-hole ad blocking, and
# Unbound recursive DNS resolver. This creates a secure VPN endpoint with
# network-wide ad blocking and privacy-focused DNS resolution.
#
# Components:
# - profile::base: Base system configuration
# - profile::wireguard: WireGuard VPN server
# - profile::pihole_native: Native Pi-hole installation for ad blocking
# - profile::unbound: Unbound recursive DNS resolver
#
# @example
#   include role::vpn_gateway
#
class role::vpn_gateway {
  include profile::base
  include profile::wireguard
  include profile::pihole_native
  include profile::unbound
}
