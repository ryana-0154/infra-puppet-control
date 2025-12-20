# @summary Webserver role
#
# Role for web servers including base configuration and web profile.
#
# @example
#   include role::webserver
#
class role::webserver {
  include profile::base
  include profile::webserver
}
