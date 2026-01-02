# @summary Manages DNS resolver configuration
#
# This profile manages /etc/resolv.conf to use the internal DNS server
# (Pi-hole/Unbound) for name resolution.
#
# @param manage_resolv
#   Whether to manage /etc/resolv.conf (default: true)
# @param nameservers
#   Array of nameserver IPs to use
# @param search_domains
#   Array of search domains
# @param options
#   Array of resolver options
#
# @example Basic usage with Hiera
#   profile::dns::manage_resolv: true
#   profile::dns::nameservers:
#     - '10.10.10.1'
#
class profile::dns (
  Boolean $manage_resolv = true,
  Array[Stdlib::IP::Address] $nameservers = ['10.10.10.1'],
  Array[String] $search_domains = ['ra-home.co.uk'],
  Array[String] $options = ['ndots:1', 'timeout:2', 'attempts:2'],
) {
  if $manage_resolv {
    # Manage /etc/resolv.conf
    file { '/etc/resolv.conf':
      ensure  => file,
      owner   => 'root',
      group   => 'root',
      mode    => '0644',
      content => template('profile/dns/resolv.conf.erb'),
    }
  }
}
