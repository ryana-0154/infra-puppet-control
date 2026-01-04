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
  Optional[Boolean] $manage_acme = undef,
  Optional[String[1]] $acme_host = undef,
  Optional[Boolean] $use_staging = undef,
  Optional[String[1]] $contact_email = undef,
  Optional[Hash[String, Hash]] $profiles = undef,
  Optional[Hash[String, Hash]] $certificates = undef,
  Optional[Integer[0,23]] $renew_cron_hour = undef,
) {
  # Check top-scope for ENC parameters first, then Hiera, then defaults
  $_manage_acme = pick($manage_acme, getvar('profile::acme_server::manage_acme'), false)
  $_acme_host = pick($acme_host, getvar('profile::acme_server::acme_host'), $facts['networking']['fqdn'])
  $_use_staging = pick($use_staging, getvar('profile::acme_server::use_staging'), false)
  $_contact_email = pick($contact_email, getvar('profile::acme_server::contact_email'), undef)
  $_profiles = pick($profiles, getvar('profile::acme_server::profiles'), {})
  $_certificates = pick($certificates, getvar('profile::acme_server::certificates'), {})
  $_renew_cron_hour = pick($renew_cron_hour, getvar('profile::acme_server::renew_cron_hour'), 2)

  if $_manage_acme {
    # Validate contact_email is provided
    if !$_contact_email {
      fail('profile::acme_server: contact_email is required when manage_acme is true')
    }

    # Create ACME account for Let's Encrypt
    # The markt-acme module requires accounts to be defined in the main acme class
    # Certificates reference accounts via the use_account parameter
    $account_name = 'default'
    $accounts = {
      $account_name => {
        'email' => $_contact_email,
        'ca'    => $_use_staging ? {
          true    => 'letsencrypt_test',
          default => 'letsencrypt',
        },
      }
    }

    # Install acme.sh on Puppet Server with account configuration
    class { 'acme':
      acme_host => $_acme_host,
      accounts  => $accounts,
      profiles  => $_profiles,
    }

    # Create certificate resources from configuration
    # Each certificate will be requested via acme.sh and made available
    # for deployment to nodes via exported resources
    $_certificates.each |String $cert_name, Hash $cert_config| {
      # Ensure use_account is set (default to 'default' account if not specified)
      # The use_account parameter is required by acme::certificate
      $cert_config_full = $cert_config + {
        'use_account' => pick($cert_config['use_account'], $account_name),
      }

      acme::certificate { $cert_name:
        * => $cert_config_full,
      }
    }

    # Ensure acme.sh cron job runs daily for automatic renewal
    # Certificates are renewed automatically 30 days before expiry
    cron { 'acme_renewal':
      command => '/root/.acme.sh/acme.sh --cron --home /root/.acme.sh > /dev/null',
      user    => 'root',
      hour    => $_renew_cron_hour,
      minute  => 0,
      require => Class['acme'],
    }
  }
}
