# @summary Manages monitoring infrastructure
#
# This profile sets up monitoring directories and related infrastructure.
#
# @param manage_monitoring
#   Whether to manage monitoring configuration
# @param monitoring_dir
#   Base directory for monitoring tools and data
# @param monitoring_dir_owner
#   Owner of the monitoring directory
# @param monitoring_dir_group
#   Group of the monitoring directory
# @param monitoring_dir_mode
#   File mode for the monitoring directory
#
# @example Basic usage
#   include profile::monitoring
#
# @example With custom directory via Hiera
#   profile::monitoring::monitoring_dir: '/opt/custom-monitoring'
#
class profile::monitoring (
  Boolean $manage_monitoring       = lookup('profile::monitoring::manage_monitoring', Boolean, 'first', true),
  Stdlib::Absolutepath $monitoring_dir = lookup('profile::monitoring::monitoring_dir', Stdlib::Absolutepath, 'first', '/opt/monitoring'),
  String[1] $monitoring_dir_owner  = lookup('profile::monitoring::monitoring_dir_owner', String[1], 'first', 'root'),
  String[1] $monitoring_dir_group  = lookup('profile::monitoring::monitoring_dir_group', String[1], 'first', 'root'),
  String[4,4] $monitoring_dir_mode = lookup('profile::monitoring::monitoring_dir_mode', String[4,4], 'first', '0755'),
) {
  if $manage_monitoring {
    # Ensure the monitoring directory exists
    file { $monitoring_dir:
      ensure => directory,
      owner  => $monitoring_dir_owner,
      group  => $monitoring_dir_group,
      mode   => $monitoring_dir_mode,
    }
  }
}
