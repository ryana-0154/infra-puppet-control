# @summary VPS role for virtual private servers
#
# This role is applied to VPS instances that require
# base configuration plus monitoring infrastructure.
#
# @example
#   include role::vps
#
class role::vps {
  include profile::base
  include profile::monitoring
}
