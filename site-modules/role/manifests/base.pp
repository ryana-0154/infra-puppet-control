# @summary Base role applied to all nodes
#
# This role contains the minimum configuration that should be
# applied to every node in the infrastructure.
#
# @example
#   include role::base
#
class role::base {
  include profile::base
  include profile::dotfiles
}
