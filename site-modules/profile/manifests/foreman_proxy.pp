# @summary Manages Foreman Smart Proxy for DNS/DHCP/TFTP/Puppet integration
#
# This profile manages Foreman Smart Proxy which provides integration with
# infrastructure services like DNS, DHCP, TFTP, and Puppet. It wraps the
# theforeman-foreman_proxy module to provide data-driven configuration.
#
# @param manage_proxy
#   Whether to manage Foreman Smart Proxy installation (default: false)
# @param foreman_base_url
#   Base URL of the Foreman server (e.g., 'https://foreman.example.com')
# @param register_in_foreman
#   Whether to register this proxy in Foreman (default: true)
# @param manage_dns
#   Whether to enable DNS management features (default: false)
# @param dns_provider
#   DNS provider to use (nsupdate, route53, etc.) (default: 'nsupdate')
# @param dns_server
#   DNS server IP address for nsupdate provider (default: '127.0.0.1')
# @param dns_ttl
#   TTL for DNS records in seconds (default: 86400)
# @param manage_dhcp
#   Whether to enable DHCP management features (default: false)
# @param manage_tftp
#   Whether to enable TFTP management features (default: false)
# @param manage_puppet
#   Whether to enable Puppet integration (default: true)
# @param oauth_consumer_key
#   OAuth consumer key for Foreman API authentication (Sensitive, from Foreman)
# @param oauth_consumer_secret
#   OAuth consumer secret for Foreman API authentication (Sensitive, from Foreman)
# @param proxy_ssl_ca
#   Path to SSL CA certificate (default: Puppet CA)
# @param proxy_ssl_cert
#   Path to SSL proxy certificate (default: Puppet cert)
# @param proxy_ssl_key
#   Path to SSL private key (default: Puppet key)
#
# @example Basic usage with Hiera
#   profile::foreman_proxy::manage_proxy: true
#   profile::foreman_proxy::foreman_base_url: 'https://foreman.example.com'
#   profile::foreman_proxy::manage_dns: true
#   profile::foreman_proxy::dns_provider: 'nsupdate'
#   profile::foreman_proxy::oauth_consumer_key: 'ENC[PKCS7,...]'
#   profile::foreman_proxy::oauth_consumer_secret: 'ENC[PKCS7,...]'
#
class profile::foreman_proxy (
  Boolean                                      $manage_proxy           = false,
  Stdlib::HTTPUrl                              $foreman_base_url       = "https://${facts['networking']['fqdn']}",
  Boolean                                      $register_in_foreman    = true,
  Boolean                                      $manage_dns             = false,
  String[1]                                    $dns_provider           = 'nsupdate',
  Stdlib::IP::Address                          $dns_server             = '127.0.0.1',
  Integer[1]                                   $dns_ttl                = 86400,
  Boolean                                      $manage_dhcp            = false,
  Boolean                                      $manage_tftp            = false,
  Boolean                                      $manage_puppet          = true,
  Variant[String[1], Sensitive[String[1]]]    $oauth_consumer_key     = Sensitive('changeme'),
  Variant[String[1], Sensitive[String[1]]]    $oauth_consumer_secret  = Sensitive('changeme'),
  Optional[Stdlib::Absolutepath]               $proxy_ssl_ca           = undef,
  Optional[Stdlib::Absolutepath]               $proxy_ssl_cert         = undef,
  Optional[Stdlib::Absolutepath]               $proxy_ssl_key          = undef,
) {
  if $manage_proxy {
    # Handle both plain strings (from eyaml) and Sensitive types
    # eyaml-encrypted values come back as plain strings, so wrap them
    $oauth_consumer_key_sensitive = $oauth_consumer_key ? {
      Sensitive => $oauth_consumer_key,
      default   => Sensitive($oauth_consumer_key),
    }
    $oauth_consumer_secret_sensitive = $oauth_consumer_secret ? {
      Sensitive => $oauth_consumer_secret,
      default   => Sensitive($oauth_consumer_secret),
    }

    # Validate required OAuth credentials
    $consumer_key_unwrapped = $oauth_consumer_key_sensitive.unwrap
    $consumer_secret_unwrapped = $oauth_consumer_secret_sensitive.unwrap

    if $consumer_key_unwrapped == 'changeme' {
      fail('profile::foreman_proxy::oauth_consumer_key must be set and encrypted with eyaml')
    }
    if $consumer_secret_unwrapped == 'changeme' {
      fail('profile::foreman_proxy::oauth_consumer_secret must be set and encrypted with eyaml')
    }

    # Main Foreman Smart Proxy class
    class { 'foreman_proxy':
      foreman_base_url      => $foreman_base_url,
      registered_name       => $facts['networking']['fqdn'],
      registered_proxy_url  => "https://${facts['networking']['fqdn']}:8443",
      oauth_effective_user  => 'admin',
      oauth_consumer_key    => $consumer_key_unwrapped,
      oauth_consumer_secret => $consumer_secret_unwrapped,
      ssl_ca                => pick($proxy_ssl_ca, '/etc/puppetlabs/puppet/ssl/certs/ca.pem'),
      ssl_cert              => pick($proxy_ssl_cert, "/etc/puppetlabs/puppet/ssl/certs/${facts['networking']['fqdn']}.pem"),
      ssl_key               => pick($proxy_ssl_key, "/etc/puppetlabs/puppet/ssl/private_keys/${facts['networking']['fqdn']}.pem"),
      register_in_foreman   => $register_in_foreman,
      # Feature toggles
      dns                   => $manage_dns,
      dhcp                  => $manage_dhcp,
      tftp                  => $manage_tftp,
      puppet                => $manage_puppet,
      puppetca              => $manage_puppet,
      # DNS provider configuration
      dns_provider          => $dns_provider,
      dns_server            => $dns_server,
      dns_ttl               => $dns_ttl,
    }

    # Note: Service management is handled by the foreman_proxy class itself
    # No need to declare service resource here
  }
}
