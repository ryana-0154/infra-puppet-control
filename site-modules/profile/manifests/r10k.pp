# @summary Manages r10k for Puppet control repository deployment
#
# This profile manages r10k installation and configuration for deploying
# Puppet control repositories from Git. It's typically used on Puppet Servers
# to deploy code environments.
#
# @param manage_r10k
#   Whether to manage r10k installation and configuration (default: false)
# @param git_remote
#   Git repository URL for the control repository
# @param basedir
#   Directory where r10k deploys environments (default: /etc/puppetlabs/code/environments)
# @param cachedir
#   Directory for r10k cache (default: /var/cache/r10k)
# @param sources
#   Hash of r10k sources (default: { puppet: { remote: $git_remote, basedir: $basedir } })
# @param auto_deploy
#   Whether to automatically deploy on first run (default: false)
# @param manage_cron
#   Whether to set up a cron job for automatic deployments (default: false)
# @param cron_minute
#   Cron schedule for automatic deployments (default: '*/15' = every 15 minutes)
# @param cron_hour
#   Cron hour schedule (default: '*' = every hour)
#
# @example Basic usage with Hiera
#   profile::r10k::manage_r10k: true
#   profile::r10k::git_remote: 'https://github.com/example/puppet-control.git'
#
class profile::r10k (
  Boolean $manage_r10k                   = false,
  Stdlib::HTTPUrl $git_remote            = 'https://github.com/ryana-0154/infra-puppet-control.git',
  Stdlib::Absolutepath $basedir          = '/etc/puppetlabs/code/environments',
  Stdlib::Absolutepath $cachedir         = '/var/cache/r10k',
  Hash $sources                          = {
    'puppet' => {
      'remote'  => $git_remote,
      'basedir' => $basedir,
    },
  },
  Boolean $auto_deploy                   = false,
  Boolean $manage_cron                   = false,
  String[1] $cron_minute                 = '*/15',
  String[1] $cron_hour                   = '*',
) {
  if $manage_r10k {
    # Install r10k as a Puppet gem
    package { 'r10k':
      ensure   => installed,
      provider => 'puppet_gem',
    }

    # Create r10k config directory
    file { '/etc/puppetlabs/r10k':
      ensure => directory,
      owner  => 'root',
      group  => 'root',
      mode   => '0755',
    }

    # Manage r10k configuration file
    file { '/etc/puppetlabs/r10k/r10k.yaml':
      ensure  => file,
      owner   => 'root',
      group   => 'root',
      mode    => '0644',
      content => template('profile/r10k/r10k.yaml.erb'),
      require => [Package['r10k'], File['/etc/puppetlabs/r10k']],
    }

    # Create cache directory
    file { $cachedir:
      ensure => directory,
      owner  => 'root',
      group  => 'root',
      mode   => '0755',
    }

    # Optionally deploy environments on first run
    if $auto_deploy {
      exec { 'r10k deploy environment':
        command     => '/opt/puppetlabs/puppet/bin/r10k deploy environment -p',
        refreshonly => true,
        subscribe   => File['/etc/puppetlabs/r10k/r10k.yaml'],
        timeout     => 600,
        require     => Package['r10k'],
      }
    }

    # Optionally set up cron job for automatic deployments
    if $manage_cron {
      cron { 'r10k-deploy':
        ensure  => present,
        command => '/opt/puppetlabs/puppet/bin/r10k deploy environment -p >> /var/log/r10k-cron.log 2>&1',
        user    => 'root',
        minute  => $cron_minute,
        hour    => $cron_hour,
        require => Package['r10k'],
      }

      # Create log file with proper permissions
      file { '/var/log/r10k-cron.log':
        ensure => file,
        owner  => 'root',
        group  => 'root',
        mode   => '0644',
      }
    }
  }
}
