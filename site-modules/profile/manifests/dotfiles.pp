# @summary Manages dotfiles deployment for users
#
# This profile clones a dotfiles repository and runs the install script
# to create symlinks in user home directories. Supports multiple users
# with individual configuration.
#
# @param manage_dotfiles
#   Whether to manage dotfiles configuration
# @param dotfiles_repo
#   Git repository URL for dotfiles
# @param dotfiles_revision
#   Git branch, tag, or commit to checkout
# @param dotfiles_dir_name
#   Directory name for cloned repo (relative to home)
# @param dotfiles_users
#   Hash of users to configure dotfiles for
#   Example:
#     ryan:
#       home_dir: /home/ryan
#       ensure: present
# @param auto_update
#   Whether to automatically pull latest changes on each Puppet run
# @param install_git
#   Whether to ensure git package is installed
#
# @example Basic usage
#   include profile::dotfiles
#
# @example Custom configuration via Hiera
#   profile::dotfiles::dotfiles_users:
#     ryan:
#       home_dir: /home/ryan
#     alice:
#       home_dir: /home/alice
#
class profile::dotfiles (
  Boolean              $manage_dotfiles   = true,
  String[1]            $dotfiles_repo     = 'https://github.com/ryana-0154/dotfiles.git',
  String[1]            $dotfiles_revision = 'main',
  String[1]            $dotfiles_dir_name = '.dotfiles',
  Hash[String[1], Hash] $dotfiles_users   = {},
  Boolean              $auto_update       = false,
  Boolean              $install_git       = true,
) {
  if $manage_dotfiles {
    # Ensure git is installed
    if $install_git {
      ensure_packages(['git'])
    }

    # Configure dotfiles for each user
    $dotfiles_users.each |String $username, Hash $user_config| {
      $home_dir = $user_config.dig('home_dir').lest || { "/home/${username}" }
      $ensure = $user_config.dig('ensure').lest || { 'present' }

      if $ensure == 'present' {
        $dotfiles_path = "${home_dir}/${dotfiles_dir_name}"

        # Determine if we can run as a different user (requires root)
        $exec_user = $facts['identity']['user'] ? {
          'root'  => $username,
          default => undef,
        }

        # Check if directory exists but is not a git repo - warn and skip if so
        # This exec only runs (and warns) if the path exists but .git doesn't
        exec { "dotfiles-check-${username}":
          command   => "echo 'Warning: ${dotfiles_path} exists but is not a git repository. Skipping dotfiles management for ${username}. Remove or rename the directory if you want Puppet to manage it.' >&2",
          path      => ['/usr/bin', '/bin'],
          onlyif    => "test -e '${dotfiles_path}' && test ! -d '${dotfiles_path}/.git'",
          loglevel  => 'warning',
          logoutput => true,
        }

        # Clone dotfiles repository (only if directory doesn't exist)
        exec { "clone-dotfiles-${username}":
          command => "git clone --branch '${dotfiles_revision}' '${dotfiles_repo}' '${dotfiles_path}'",
          path    => ['/usr/bin', '/bin'],
          user    => $exec_user,
          creates => "${dotfiles_path}/.git",
          unless  => "test -e '${dotfiles_path}'",
          require => Exec["dotfiles-check-${username}"],
        }

        # Update dotfiles repository (only if auto_update is true and it's a valid git repo)
        if $auto_update {
          exec { "update-dotfiles-${username}":
            command => "git fetch origin && git checkout '${dotfiles_revision}' && git pull origin '${dotfiles_revision}'",
            cwd     => $dotfiles_path,
            path    => ['/usr/bin', '/bin'],
            user    => $exec_user,
            onlyif  => "test -d '${dotfiles_path}/.git'",
            require => Exec["clone-dotfiles-${username}"],
          }
        }

        # Run install script to create symlinks (only if repo exists)
        exec { "install-dotfiles-${username}":
          command     => './install',
          cwd         => $dotfiles_path,
          path        => ['/usr/bin', '/usr/local/bin', '/bin'],
          user        => $exec_user,
          environment => ["HOME=${home_dir}"],
          refreshonly => true,
          subscribe   => Exec["clone-dotfiles-${username}"],
          onlyif      => "test -d '${dotfiles_path}/.git'",
        }

        # Ensure install script is executable (only if repo exists)
        exec { "chmod-dotfiles-install-${username}":
          command => "chmod 755 '${dotfiles_path}/install'",
          path    => ['/usr/bin', '/bin'],
          onlyif  => "test -f '${dotfiles_path}/install' && test ! -x '${dotfiles_path}/install'",
          before  => Exec["install-dotfiles-${username}"],
        }
      } elsif $ensure == 'absent' {
        # Remove dotfiles directory
        file { "${home_dir}/${dotfiles_dir_name}":
          ensure  => absent,
          force   => true,
          recurse => true,
        }
      }
    }
  }
}
