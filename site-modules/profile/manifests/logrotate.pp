# @summary Manages log rotation configuration
#
# This profile configures logrotate for managing log files across the system.
# It sets up default rotation policies and can manage custom log rotation rules.
#
# @param manage_logrotate
#   Whether to manage logrotate configuration
# @param rotate_period
#   How often to rotate logs (daily, weekly, monthly)
# @param rotate_count
#   Number of rotated logs to keep
# @param compress
#   Whether to compress rotated logs
# @param delaycompress
#   Delay compression until next rotation cycle
# @param create_mode
#   File mode for newly created log files
# @param create_owner
#   Owner for newly created log files
# @param create_group
#   Group for newly created log files
# @param rules
#   Hash of custom logrotate rules to manage
#
# @example Basic usage
#   include profile::logrotate
#
# @example With custom rules via Hiera
#   profile::logrotate::rules:
#     apache2:
#       path: '/var/log/apache2/*.log'
#       rotate: 14
#       compress: true
#
class profile::logrotate (
  Boolean     $manage_logrotate = true,
  String[1]   $rotate_period    = 'weekly',
  Integer[1]  $rotate_count     = 4,
  Boolean     $compress         = true,
  Boolean     $delaycompress    = true,
  String[4,4] $create_mode      = '0640',
  String[1]   $create_owner     = 'root',
  String[1]   $create_group     = 'adm',
  Hash        $rules            = {},
) {
  if $manage_logrotate {
    # Manage the logrotate package and base configuration
    class { 'logrotate':
      ensure => present,
      config => {
        'rotate'        => $rotate_count,
        'rotate_every'  => $rotate_period,  # daily, weekly, or monthly
        'compress'      => $compress,
        'delaycompress' => $delaycompress,
        'create'        => true,
        'create_mode'   => $create_mode,
        'create_owner'  => $create_owner,
        'create_group'  => $create_group,
        'dateext'       => true,
        'dateformat'    => '-%Y%m%d',
      },
    }

    # Create custom logrotate rules from Hiera
    $rules.each |String $name, Hash $config| {
      logrotate::rule { $name:
        * => $config,
      }
    }
  }
}
