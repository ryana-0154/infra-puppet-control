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

        # Determine vcsrepo ensure value
        $vcsrepo_ensure = $auto_update ? {
          true    => 'latest',
          default => 'present',
        }

        # Clone/update dotfiles repository
        vcsrepo { $dotfiles_path:
          ensure   => $vcsrepo_ensure,
          provider => 'git',
          source   => $dotfiles_repo,
          revision => $dotfiles_revision,
          user     => $username,
        }

        # Determine if we can run as a different user (requires root)
        # In production, Puppet runs as root and can execute as other users
        # In CI/non-root environments, omit user parameter to allow catalog compilation
        $exec_user = $facts['identity']['user'] ? {
          'root'  => $username,
          default => undef,
        }

        # Run install script to create symlinks
        exec { "install-dotfiles-${username}":
          command     => './install',
          cwd         => $dotfiles_path,
          path        => ['/usr/bin', '/usr/local/bin', '/bin'],
          user        => $exec_user,
          environment => ["HOME=${home_dir}"],
          # Only run if dotfiles were just cloned/updated or symlinks don't exist
          refreshonly => true,
          subscribe   => Vcsrepo[$dotfiles_path],
          require     => Vcsrepo[$dotfiles_path],
        }

        # Ensure install script is executable
        file { "${dotfiles_path}/install":
          ensure  => file,
          mode    => '0755',
          require => Vcsrepo[$dotfiles_path],
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
