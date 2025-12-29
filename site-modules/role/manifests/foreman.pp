# @summary Foreman ENC server role
#
# This role is applied to nodes running Foreman as an External Node Classifier
# (ENC) with web UI, PostgreSQL database backend, Puppet Server integration,
# and Smart Proxy for infrastructure service management.
#
# Composed profiles:
# - profile::base - Base system configuration
# - profile::postgresql - PostgreSQL database server for Foreman backend
# - profile::foreman - Foreman server with ENC and web UI
# - profile::foreman_proxy - Smart Proxy for DNS/DHCP/Puppet integration
#
# @example Apply to a node via site.pp
#   node 'foreman.example.com' {
#     include role::foreman
#   }
#
class role::foreman {
  include profile::base
  include profile::postgresql
  include profile::foreman
  include profile::foreman_proxy

  # Explicit ordering to ensure proper dependency chain
  # PostgreSQL must be running before Foreman installs
  # Foreman must be available before Smart Proxy registers
  Class['profile::base']
    -> Class['profile::postgresql']
    -> Class['profile::foreman']
    -> Class['profile::foreman_proxy']
}
