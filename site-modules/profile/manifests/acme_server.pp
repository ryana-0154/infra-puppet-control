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
  # Multi-source parameter resolution (priority order):
  # 1. Top-scope variables from Foreman ENC parameters (e.g., $::acme_manage_acme)
  # 2. Hiera data (profile::acme_server::manage_acme)
  # 3. Class parameter defaults
  #
  # To configure via Foreman: Set host/hostgroup parameters:
  #   acme_manage_acme, acme_use_staging, acme_contact_email, etc.

  # Boolean parameters - use pick() with explicit type checking
  $_manage_acme = pick(
    getvar('acme_manage_acme'),
    lookup('profile::acme_server::manage_acme', Optional[Boolean], 'first', undef),
    $manage_acme
  )

  $_use_staging = pick(
    getvar('acme_use_staging'),
    lookup('profile::acme_server::use_staging', Optional[Boolean], 'first', undef),
    $use_staging
  )

  # String parameters
  $_acme_host = pick(
    getvar('acme_host'),
    lookup('profile::acme_server::acme_host', Optional[String[1]], 'first', undef),
    $acme_host
  )

  $_contact_email = pick(
    getvar('acme_contact_email'),
    lookup('profile::acme_server::contact_email', Optional[String[1]], 'first', undef),
    $contact_email
  )

  # Integer parameter
  $_renew_cron_hour = pick(
    getvar('acme_renew_cron_hour'),
    lookup('profile::acme_server::renew_cron_hour', Optional[Integer[0,23]], 'first', undef),
    $renew_cron_hour
  )

  # Hash parameters - use deep merge for profiles and certificates
  $enc_profiles = getvar('acme_profiles')
  $hiera_profiles = lookup('profile::acme_server::profiles', Optional[Hash[String, Hash]], 'deep', undef)
  $_profiles = deep_merge(
    $profiles,  # Defaults
    $hiera_profiles ? { NotUndef => $hiera_profiles, default => {} },
    $enc_profiles ? { NotUndef => $enc_profiles, default => {} }
  )

  $enc_certificates = getvar('acme_certificates')
  $hiera_certificates = lookup('profile::acme_server::certificates', Optional[Hash[String, Hash]], 'deep', undef)
  $_certificates = deep_merge(
    $certificates,  # Defaults
    $hiera_certificates ? { NotUndef => $hiera_certificates, default => {} },
    $enc_certificates ? { NotUndef => $enc_certificates, default => {} }
  )

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

    # Workaround for OCSP fetching failures
    # Let's Encrypt ended OCSP must-staple support in Dec 2024, causing OCSP
    # responder failures. Pre-create OCSP files with far-future timestamps
    # so the acme module's unless condition skips the fetch attempt.
    # Use exec (not file resource) to avoid duplicate declaration with acme::request::ocsp
    # This exec runs before acme class, creating placeholder that prevents OCSP fetch
    $_certificates.each |String $cert_name, Hash $cert_config| {
      exec { "create_ocsp_placeholder_${cert_name}":
        command => "/bin/sh -c \"mkdir -p /etc/acme.sh/results && printf '# OCSP stapling disabled - LetsEncrypt ended support Dec 2024\\n' > /etc/acme.sh/results/${cert_name}.ocsp && chown acme:acme /etc/acme.sh/results/${cert_name}.ocsp && chmod 644 /etc/acme.sh/results/${cert_name}.ocsp && touch -d 2030-01-01 /etc/acme.sh/results/${cert_name}.ocsp\"",
        unless  => "/usr/bin/test -f /etc/acme.sh/results/${cert_name}.ocsp && /usr/bin/test \$(/usr/bin/stat -c %Y /etc/acme.sh/results/${cert_name}.ocsp) -gt \$(/usr/bin/date +%s)",
      }
    }
  }
}
