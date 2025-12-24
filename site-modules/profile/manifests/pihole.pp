# @summary Manages PiHole provisioning and configuration
#
# This profile handles PiHole configuration provisioning from a teleporter backup.
# It deploys configuration files, blocklists, and custom hosts to a PiHole instance.
#
# @param manage_pihole
#   Whether to manage PiHole configuration (default: false)
# @param pihole_config_dir
#   Directory where PiHole stores its configuration
# @param pihole_password_hash
#   PiHole API password hash (should be encrypted with eyaml)
# @param pihole_container_name
#   Name of the PiHole Docker container
# @param provision_gravity_db
#   Whether to provision the gravity database (blocklists/whitelists)
# @param provision_custom_hosts
#   Whether to provision custom hosts file
# @param restart_on_config_change
#   Whether to restart PiHole when configuration changes
#
# @example Basic usage
#   include profile::pihole
#
# @example With custom parameters via Hiera
#   profile::pihole::pihole_password_hash: >
#     ENC[PKCS7,MIIBeQYJKoZIhvcNAQcDoIIBajCCAWYCAQAxggEhMIIBHQIBADAFMAACAQEw...]
#
class profile::pihole (
  Boolean                  $manage_pihole              = false,
  Stdlib::Absolutepath     $pihole_config_dir          = '/etc/pihole',
  Optional[String[1]]      $pihole_password_hash       = undef,
  String[1]                $pihole_container_name      = 'pihole',
  Boolean                  $provision_gravity_db       = true,
  Boolean                  $provision_custom_hosts     = true,
  Boolean                  $restart_on_config_change   = true,
) {
  # Validate that password hash is provided
  if $manage_pihole and !$pihole_password_hash {
    fail('profile::pihole: pihole_password_hash is required when manage_pihole is true')
  }

  if $manage_pihole {
    # Determine notify target
    $notify_target = $restart_on_config_change ? {
      true    => Exec['restart-pihole'],
      default => undef,
    }

    # Ensure PiHole configuration directory exists
    file { $pihole_config_dir:
      ensure => directory,
      owner  => 'root',
      group  => 'root',
      mode   => '0755',
    }

    # Deploy PiHole configuration
    file { "${pihole_config_dir}/pihole.toml":
      ensure  => file,
      content => template('profile/pihole/pihole.toml.erb'),
      owner   => 'root',
      group   => 'root',
      mode    => '0644',
      require => File[$pihole_config_dir],
      notify  => $notify_target,
    }

    # Provision gravity database (blocklists/whitelists)
    if $provision_gravity_db {
      file { "${pihole_config_dir}/gravity.db":
        ensure  => file,
        source  => 'puppet:///modules/profile/pihole/gravity.db',
        owner   => 'pihole',
        group   => 'pihole',
        mode    => '0644',
        require => File[$pihole_config_dir],
        notify  => $notify_target,
      }
    }

    # Provision custom hosts
    if $provision_custom_hosts {
      file { "${pihole_config_dir}/custom.list":
        ensure  => file,
        source  => 'puppet:///modules/profile/pihole/custom_hosts',
        owner   => 'root',
        group   => 'root',
        mode    => '0644',
        require => File[$pihole_config_dir],
        notify  => $notify_target,
      }
    }

    # Restart PiHole container when configuration changes
    exec { 'restart-pihole':
      command     => "/usr/bin/docker restart ${pihole_container_name}",
      refreshonly => true,
      path        => ['/usr/bin', '/usr/sbin', '/bin', '/sbin'],
    }
  }
}
