# @summary Manages automatic security updates via unattended-upgrades
#
# This profile configures unattended-upgrades to automatically install
# security updates on Debian/Ubuntu systems. This is a security best practice
# mentioned in the WireGuard VPN setup guide.
#
# @param manage_unattended_upgrades
#   Whether to manage unattended-upgrades configuration (default: false)
# @param auto_fix_interrupted_dpkg
#   Whether to automatically fix interrupted dpkg processes
# @param enable_auto_updates
#   Whether to enable automatic updates (default: true)
# @param update_interval
#   How often to check for updates (in days)
# @param download_upgradeable
#   Whether to download upgradeable packages automatically
# @param auto_clean_interval
#   How often to run apt-get autoclean (in days, 0 = disabled)
# @param origins
#   Array of origin patterns for automatic updates
# @param blacklist
#   Array of packages to exclude from automatic updates
# @param email
#   Email address to send upgrade notifications to
# @param mail_only_on_error
#   Only send email on errors (default: true)
# @param remove_unused_kernel_packages
#   Automatically remove unused kernel packages
# @param remove_unused_dependencies
#   Automatically remove unused dependencies
# @param automatic_reboot
#   Whether to automatically reboot when required (default: false for VPS)
# @param automatic_reboot_time
#   Time to reboot if automatic_reboot is enabled (e.g., '02:00')
#
# @example Basic usage
#   include profile::unattended_upgrades
#
# @example With custom parameters via Hiera
#   profile::unattended_upgrades::manage_unattended_upgrades: true
#   profile::unattended_upgrades::automatic_reboot: true
#   profile::unattended_upgrades::automatic_reboot_time: '03:00'
#
class profile::unattended_upgrades (
  Boolean                  $manage_unattended_upgrades      = false,
  Boolean                  $auto_fix_interrupted_dpkg       = true,
  Boolean                  $enable_auto_updates             = true,
  Integer[1]               $update_interval                 = 1,
  Boolean                  $download_upgradeable            = true,
  Integer[0]               $auto_clean_interval             = 7,
  Array[String[1]]         $origins                         = [
    "\${distro_id}:\${distro_codename}-security",
    "\${distro_id}ESMApps:\${distro_codename}-apps-security",
    "\${distro_id}ESM:\${distro_codename}-infra-security",
  ],
  Array[String[1]]         $blacklist                       = [],
  Optional[String[1]]      $email                           = undef,
  Boolean                  $mail_only_on_error              = true,
  Boolean                  $remove_unused_kernel_packages   = true,
  Boolean                  $remove_unused_dependencies      = true,
  Boolean                  $automatic_reboot                = false,
  String[1]                $automatic_reboot_time           = '02:00',
) {
  if $manage_unattended_upgrades {
    # Use the apt module to configure unattended-upgrades
    class { 'apt':
      update => {
        frequency => 'daily',
      },
    }

    class { 'apt::unattended_upgrades':
      auto_fix_interrupted_dpkg     => $auto_fix_interrupted_dpkg,
      enable                        => $enable_auto_updates,
      update                        => $update_interval,
      download_upgradeable          => $download_upgradeable,
      auto_clean_interval           => $auto_clean_interval,
      origins                       => $origins,
      blacklist                     => $blacklist,
      mail                          => $email,
      mail_only_on_error            => $mail_only_on_error,
      remove_unused_kernel_packages => $remove_unused_kernel_packages,
      remove_unused_dependencies    => $remove_unused_dependencies,
      automatic_reboot              => $automatic_reboot,
      automatic_reboot_time         => $automatic_reboot_time,
    }
  }
}
