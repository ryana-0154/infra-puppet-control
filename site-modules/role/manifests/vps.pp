# @summary VPS role for virtual private servers
#
# This role is applied to VPS instances that require
# base configuration, Unbound DNS resolver, and monitoring infrastructure.
#
# @example
#   include role::vps
#
class role::vps {
  include profile::base
  include profile::unbound
  include profile::monitoring
}
