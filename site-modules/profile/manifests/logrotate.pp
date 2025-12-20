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
  Boolean $manage_logrotate = lookup('profile::logrotate::manage_logrotate', Boolean, 'first', true),
  String[1] $rotate_period  = lookup('profile::logrotate::rotate_period', String[1], 'first', 'weekly'),
  Integer[1] $rotate_count  = lookup('profile::logrotate::rotate_count', Integer[1], 'first', 4),
  Boolean $compress         = lookup('profile::logrotate::compress', Boolean, 'first', true),
  Boolean $delaycompress    = lookup('profile::logrotate::delaycompress', Boolean, 'first', true),
  String[4,4] $create_mode  = lookup('profile::logrotate::create_mode', String[4,4], 'first', '0640'),
  String[1] $create_owner   = lookup('profile::logrotate::create_owner', String[1], 'first', 'root'),
  String[1] $create_group   = lookup('profile::logrotate::create_group', String[1], 'first', 'adm'),
  Hash $rules               = lookup('profile::logrotate::rules', Hash, 'first', {}),
) {
  if $manage_logrotate {
    # Manage the logrotate package and base configuration
    class { 'logrotate':
      ensure      => present,
      config      => {
        'rotate'        => $rotate_count,
        $rotate_period  => true,  # daily, weekly, or monthly
        'compress'      => $compress,
        'delaycompress' => $delaycompress,
        'create'        => "${create_mode} ${create_owner} ${create_group}",
        'dateext'       => true,
        'dateformat'    => '-%Y%m%d',
      },
      manage_wtmp => true,
      manage_btmp => true,
    }

    # Create custom logrotate rules from Hiera
    $rules.each |String $name, Hash $config| {
      logrotate::rule { $name:
        * => $config,
      }
    }
  }
}
