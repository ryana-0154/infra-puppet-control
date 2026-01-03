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
#   Hash of certificate requests to manage
#
# @param renew_cron_hour
#   Hour to run certificate renewal check (default: 2 = 2 AM)
#
# @example Basic usage via Hiera (staging)
#   profile::acme_server::manage_acme: true
#   profile::acme_server::use_staging: true
#   profile::acme_server::contact_email: 'admin@ra-home.co.uk'
#   profile::acme_server::profiles:
#     cloudflare_dns01:
#       challengetype: 'dns-01'
#       hook: 'dns_cf'
#       env:
#         CF_Token: "%{lookup('acme::cloudflare_api_token')}"
#
# @example Production wildcard certificate
#   profile::acme_server::use_staging: false
#   profile::acme_server::certificates:
#     wildcard_ra_home:
#       use_profile: 'cloudflare_dns01'
#       domain: '*.ra-home.co.uk'
#       domain_alias: ['ra-home.co.uk']
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
  if $manage_acme {
    # Validate contact_email is provided for production
    if !$use_staging and !$contact_email {
      fail('profile::acme_server: contact_email is required when use_staging is false')
    }

    # Determine CA URL based on staging flag
    $ca_url = $use_staging ? {
      true    => 'https://acme-staging-v02.api.letsencrypt.org/directory',
      default => 'https://acme-v02.api.letsencrypt.org/directory',
    }

    # Install acme.sh on Puppet Server
    class { 'acme':
      acme_host => $acme_host,
      ca_url    => $ca_url,
      email     => $contact_email,
      profiles  => $profiles,
    }

    # Create certificate resources from Hiera
    # Each certificate will be requested via acme.sh and made available
    # for deployment to nodes via exported resources
    $certificates.each |String $cert_name, Hash $cert_config| {
      acme::certificate { $cert_name:
        * => $cert_config,
      }
    }

    # Ensure acme.sh cron job runs daily for automatic renewal
    # Certificates are renewed automatically 30 days before expiry
    cron { 'acme_renewal':
      command => '/root/.acme.sh/acme.sh --cron --home /root/.acme.sh > /dev/null',
      user    => 'root',
      hour    => $renew_cron_hour,
      minute  => 0,
      require => Class['acme'],
    }
  }
}
