# @summary Webserver role
#
# Role for web servers including base configuration and web profile.
#
# @example
#   include role::webserver
#
class role::webserver {
  contain profile::base
  contain profile::webserver
}
