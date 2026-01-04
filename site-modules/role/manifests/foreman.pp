# @summary Foreman ENC server role
#
# This role is applied to nodes running Foreman as an External Node Classifier
# (ENC) with web UI, PostgreSQL database backend, Puppet Server integration,
# and Smart Proxy for infrastructure service management.
#
# Composed profiles:
# - profile::base - Base system configuration
# - profile::postgresql - PostgreSQL database server for Foreman backend
# - profile::puppetdb - PuppetDB for exported resources (optional, enabled via Hiera)
# - profile::foreman - Foreman server with ENC and web UI
# - profile::foreman_proxy - Smart Proxy for DNS/DHCP/Puppet integration
# - profile::acme_server - Let's Encrypt certificate management (optional, enabled via Hiera)
# - profile::acme_deploy - Deploy ACME certificates to services (optional, enabled via Hiera)
#
# @example Apply to a node via site.pp
#   node 'foreman.example.com' {
#     include role::foreman
#   }
#
class role::foreman {
  include profile::base
  include profile::postgresql
  include profile::puppetdb
  include profile::foreman
  include profile::foreman_proxy
  include profile::acme_server
  include profile::acme_deploy

  # Explicit ordering to ensure proper dependency chain
  # PostgreSQL must be running before PuppetDB and Foreman install
  # PuppetDB must be operational before ACME (for exported resources)
  # ACME server must sign certificates before they can be deployed
  # Certificates must be deployed before Foreman starts using them
  # Foreman must be available before Smart Proxy registers
  Class['profile::base']
    -> Class['profile::postgresql']
    -> Class['profile::puppetdb']
    -> Class['profile::acme_server']
    -> Class['profile::acme_deploy']
    -> Class['profile::foreman']
    -> Class['profile::foreman_proxy']
}
