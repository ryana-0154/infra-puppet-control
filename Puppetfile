# Puppetfile - Managed by r10k
# https://github.com/puppetlabs/r10k

# Forge modules
forge 'https://forge.puppet.com'

# Core modules from Puppet Forge
mod 'puppetlabs-stdlib', '9.6.0'
mod 'puppetlabs-concat', '9.0.2'
mod 'puppetlabs-resource_api', '1.1.0'
mod 'puppetlabs-ntp', '10.1.0'
mod 'puppetlabs-accounts', '8.2.1'
mod 'puppetlabs-inifile', '6.1.1'
mod 'puppetlabs-cron_core', '1.3.0'  # Cron resource type (required by puppet module)

# System management
mod 'puppet-logrotate', '7.1.0'
mod 'puppet-systemd', '7.1.0'
mod 'puppetlabs-vcsrepo', '6.1.0'

# Security modules
mod 'puppet-fail2ban', '7.0.0'
mod 'saz-ssh', '13.1.0'

# Firewall management
mod 'puppetlabs-firewall', '8.1.3'  # For profile::base
mod 'kogitoapp-ufw', '1.0.3'  # For UFW-based profiles (WireGuard)

# Sysctl management (for WireGuard IP forwarding)
mod 'puppet-augeasproviders_sysctl', '3.3.0'
mod 'puppet-augeasproviders_core', '4.2.0'

# Database management
mod 'puppetlabs-postgresql', '10.5.0'
mod 'puppetlabs-puppetdb', '8.1.0'  # PuppetDB for exported resources (required by ACME)

# Certificate management (Let's Encrypt)
mod 'markt-acme', '4.1.0'  # Let's Encrypt certificate automation
mod 'markt-marktlib', :latest  # Required dependency for markt-acme
mod 'puppet-openssl', '3.0.0'  # OpenSSL management for certificates
mod 'puppetlabs-nginx', :latest  # Nginx web server for reverse proxy (deprecated but functional)

# Foreman ENC and management (Rocky Linux 9 / EL9 compatible)
# Module versions 28.x support Foreman 3.1+ on EL9
mod 'theforeman-foreman', '28.1.0'
mod 'theforeman-foreman_proxy', '28.1.0'
mod 'theforeman-puppet', '20.1.0'
mod 'theforeman-puppetserver_foreman', '2.1.0'  # Required for Puppet Server + Foreman integration

# Foreman dependencies
mod 'puppetlabs-apt', '9.4.0'
mod 'puppet-extlib', '7.1.0'
mod 'theforeman-dns', '11.0.0'
mod 'theforeman-dhcp', '9.1.0'
mod 'theforeman-tftp', '9.1.0'
mod 'puppet-redis', '11.1.0'
mod 'puppetlabs-apache', '12.3.0'
mod 'richardc-datacat', '0.6.2'
mod 'puppet-mosquitto', '2.0.0'

# HashiCorp Vault integration for secret management
mod 'southalc-vault_lookup', '1.1.0'

# Git-based modules (examples)
# mod 'custom_module',
#   :git => 'https://github.com/org/custom_module.git',
#   :tag => 'v1.0.0'

# Homelab custom modules
mod 'homelab',
  :git => 'https://github.com/ryana-0154/homelab-puppet.git',
  :tag => 'v0.4.0'
