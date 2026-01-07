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
# @param gravity_db_owner
#   Owner for gravity.db file (use 'root' if bind-mounting into Docker)
# @param gravity_db_group
#   Group for gravity.db file (use 'root' if bind-mounting into Docker)
# @param local_domain
#   The local DNS domain used by Pi-hole (e.g., 'home', 'lan', 'local')
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
  String[1]                $gravity_db_owner           = 'root',
  String[1]                $gravity_db_group           = 'root',
  String[1]                $local_domain               = 'home',
) {
  # Validate that password hash is provided
  if $manage_pihole and !$pihole_password_hash {
    fail('profile::pihole: pihole_password_hash is required when manage_pihole is true')
  }

  # Validate password hash format
  if $manage_pihole and $pihole_password_hash {
    unless $pihole_password_hash =~ /^\$BALLOON-SHA256\$/ {
      fail('profile::pihole: pihole_password_hash must be a Balloon hash (starts with $BALLOON-SHA256$)')
    }
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
        owner   => $gravity_db_owner,
        group   => $gravity_db_group,
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
      command     => "docker restart ${pihole_container_name}",
      refreshonly => true,
      path        => ['/usr/bin', '/usr/local/bin', '/usr/sbin', '/bin', '/sbin', '/snap/bin'],
      onlyif      => "docker ps -a --format '{{.Names}}' | grep -q '^${pihole_container_name}$'",
    }
  }
}
