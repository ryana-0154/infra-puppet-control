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
# @example Basic usage via Foreman ENC Smart Class Parameters
#   Configure → Puppet Classes → profile::acme_server → Smart Class Parameters:
#   - manage_acme: true
#   - use_staging: true
#   - contact_email: 'admin@ra-home.co.uk'
#   - profiles: { cloudflare_dns01: { challengetype: 'dns-01', ... } }
#
# @example Production wildcard certificate
#   - use_staging: false
#   - certificates: { wildcard_ra_home: { use_profile: 'cloudflare_dns01', ... } }
#
class profile::acme_server {
  # Use profile::param() helper to support both Hiera and Foreman ENC Smart Class Parameters
  # This allows parameters to be set in either Hiera YAML files or Foreman UI
  $manage_acme = profile::param('profile::acme_server::manage_acme', Boolean, false)
  $acme_host = profile::param('profile::acme_server::acme_host', String[1], $facts['networking']['fqdn'])
  $use_staging = profile::param('profile::acme_server::use_staging', Boolean, false)
  $contact_email = profile::param('profile::acme_server::contact_email', Optional[String[1]], undef)
  $profiles = profile::param('profile::acme_server::profiles', Hash[String, Hash], {})
  $certificates = profile::param('profile::acme_server::certificates', Hash[String, Hash], {})
  $renew_cron_hour = profile::param('profile::acme_server::renew_cron_hour', Integer[0,23], 2)

  if $manage_acme {
    # Validate contact_email is provided for production
    if !$use_staging and !$contact_email {
      fail('profile::acme_server: contact_email is required when use_staging is false')
    }

    # Install acme.sh on Puppet Server
    # The markt-acme module handles CA URL and email through certificate resources
    class { 'acme':
      acme_host => $acme_host,
      profiles  => $profiles,
    }

    # Create certificate resources from configuration
    # Each certificate will be requested via acme.sh and made available
    # for deployment to nodes via exported resources
    $certificates.each |String $cert_name, Hash $cert_config| {
      # Add CA and email to certificate config
      $cert_config_full = $cert_config + {
        'ca'    => $use_staging ? {
          true    => 'letsencrypt_test',
          default => 'letsencrypt',
        },
        'email' => $contact_email,
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
      hour    => $renew_cron_hour,
      minute  => 0,
      require => Class['acme'],
    }
  }
}
