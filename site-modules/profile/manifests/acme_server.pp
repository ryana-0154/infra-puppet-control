# @summary ACME server for Let's Encrypt certificate management
#
# This profile configures the central ACME server on the Puppet Server
# (foreman01) for managing Let's Encrypt certificates. It uses the markt/acme
# module with DNS-01 challenges via Cloudflare for automated certificate
# issuance and renewal.
#
# Certificates are requested centrally and then deployed to nodes via
# exported resources, keeping private keys secure on the target hosts.
#
# @param manage_acme
#   Whether to manage ACME certificate automation on this node
#
# @param acme_host
#   Hostname where acme.sh will run (typically Puppet Server FQDN)
#
# @param use_staging
#   Use Let's Encrypt staging environment for testing (default: false)
#   IMPORTANT: Start with true for testing, then switch to false for production
#
# @param contact_email
#   Contact email for Let's Encrypt account (required for production)
#
# @param profiles
#   Hash of ACME challenge profiles (DNS-01, HTTP-01, etc.)
#
# @param certificates
#   Hash of certificate requests to manage. Each certificate should specify:
#   - domain: Primary domain (use space-separated string for SANs, e.g., 'example.com *.example.com')
#   - use_profile: Name of the challenge profile to use (from profiles hash)
#   - use_account: (Optional) Account name to use (defaults to 'default')
#   Example: { wildcard_ra_home: { domain: '*.ra-home.co.uk ra-home.co.uk', use_profile: 'cloudflare_dns01' } }
#
# @param renew_cron_hour
#   Hour to run certificate renewal check (default: 2 = 2 AM)
#
# @example Basic usage via Foreman ENC Smart Class Parameters
#   Configure → Puppet Classes → profile::acme_server → Smart Class Parameters:
#   - manage_acme: true
#   - use_staging: true
#   - contact_email: 'admin@ra-home.co.uk'
#   - profiles: { cloudflare_dns01: { challengetype: 'dns-01', options: { env: { CF_Token: 'xxx' } } } }
#
# @example Production wildcard certificate
#   - use_staging: false
#   - certificates: { wildcard_ra_home: { domain: '*.ra-home.co.uk ra-home.co.uk', use_profile: 'cloudflare_dns01' } }
#
class profile::acme_server (
  Boolean $manage_acme = false,
  String[1] $acme_host = $facts['networking']['fqdn'],
  Boolean $use_staging = false,
  Optional[String[1]] $contact_email = undef,
  Hash[String, Hash] $profiles = {},
  Hash[String, Hash] $certificates = {},
  Integer[0,23] $renew_cron_hour = 2,
) {
  # Use lookup() to check both Hiera AND automatic parameter lookup (which includes ENC)
  # This works because lookup checks: Hiera -> automatic parameter lookup -> defaults
  $_manage_acme = lookup('profile::acme_server::manage_acme', Boolean, 'first', $manage_acme)
  $_acme_host = lookup('profile::acme_server::acme_host', String[1], 'first', $acme_host)
  $_use_staging = lookup('profile::acme_server::use_staging', Boolean, 'first', $use_staging)
  $_contact_email = lookup('profile::acme_server::contact_email', Optional[String[1]], 'first', $contact_email)
  $_profiles = lookup('profile::acme_server::profiles', Hash[String, Hash], 'deep', $profiles)
  $_certificates = lookup('profile::acme_server::certificates', Hash[String, Hash], 'deep', $certificates)
  $_renew_cron_hour = lookup('profile::acme_server::renew_cron_hour', Integer[0,23], 'first', $renew_cron_hour)

  if $_manage_acme {
    # Validate contact_email is provided
    if !$_contact_email {
      fail('profile::acme_server: contact_email is required when manage_acme is true')
    }

    # Determine which CA to use (staging vs production)
    $default_ca = $_use_staging ? {
      true    => 'letsencrypt_test',
      default => 'letsencrypt',
    }

    # Install and configure acme.sh on Puppet Server
    # The acme module handles account registration, profile setup, and certificate requests
    class { 'acme':
      acme_host    => $_acme_host,
      accounts     => [$_contact_email],
      default_ca   => $default_ca,
      profiles     => $_profiles,
      certificates => $_certificates,
    }

    # Ensure acme.sh cron job runs daily for automatic renewal
    # Certificates are renewed automatically 60 days before expiry (module default)
    cron { 'acme_renewal':
      command => '/root/.acme.sh/acme.sh --cron --home /root/.acme.sh > /dev/null',
      user    => 'root',
      hour    => $_renew_cron_hour,
      minute  => 0,
      require => Class['acme'],
    }
  }
}
