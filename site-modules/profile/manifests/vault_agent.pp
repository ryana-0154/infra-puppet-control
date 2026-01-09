# @summary HashiCorp Vault agent for client-side secret retrieval
#
# This profile configures the Vault agent on nodes to enable Deferred
# secret lookups. Secrets are retrieved at catalog application time,
# never touching the Puppet Server.
#
# @param manage_vault
#   Whether to manage Vault agent configuration
# @param vault_addr
#   Vault server address
# @param vault_auth_method
#   Authentication method (approle, cert, token)
# @param vault_role
#   AppRole role name for authentication
# @param vault_namespace
#   Vault namespace (for Vault Enterprise)
# @param auto_auth
#   Enable automatic authentication
# @param cache_enable
#   Enable response caching
# @param cache_use_auto_auth_token
#   Use auto-auth token for caching
#
# @example Basic usage via Foreman
#   In Foreman hostgroup parameters:
#   - vault_manage: true
#   - vault_addr: https://vault.example.com:8200
#   - vault_role: puppet-nodes
#
class profile::vault_agent (
  Boolean $manage_vault                = false,
  String[1] $vault_addr                = 'https://vault.example.com:8200',
  Enum['approle', 'cert', 'token'] $vault_auth_method = 'approle',
  String[1] $vault_role                = 'puppet',
  Optional[String[1]] $vault_namespace = undef,
  Boolean $auto_auth                   = true,
  Boolean $cache_enable                = true,
  Boolean $cache_use_auto_auth_token   = true,
) {
  # Foreman ENC -> Hiera -> Default resolution
  $_manage_vault_enc = getvar('vault_agent_manage')
  $_manage_vault = $_manage_vault_enc ? {
    undef   => $manage_vault,
    default => $_manage_vault_enc,
  }

  $_vault_addr_enc = getvar('vault_addr')
  $_vault_addr = $_vault_addr_enc ? {
    undef   => $vault_addr,
    default => $_vault_addr_enc,
  }

  $_vault_auth_method_enc = getvar('vault_auth_method')
  $_vault_auth_method = $_vault_auth_method_enc ? {
    undef   => $vault_auth_method,
    default => $_vault_auth_method_enc,
  }

  $_vault_role_enc = getvar('vault_role')
  $_vault_role = $_vault_role_enc ? {
    undef   => $vault_role,
    default => $_vault_role_enc,
  }

  if $_manage_vault {
    # Ensure Vault agent directory exists
    file { '/etc/vault.d':
      ensure => directory,
      owner  => 'root',
      group  => 'root',
      mode   => '0755',
    }

    # Vault agent configuration
    file { '/etc/vault.d/agent.hcl':
      ensure  => file,
      owner   => 'root',
      group   => 'root',
      mode    => '0640',
      content => epp('profile/vault/agent.hcl.epp', {
        vault_addr                => $_vault_addr,
        vault_auth_method         => $_vault_auth_method,
        vault_role                => $_vault_role,
        vault_namespace           => $vault_namespace,
        auto_auth                 => $auto_auth,
        cache_enable              => $cache_enable,
        cache_use_auto_auth_token => $cache_use_auto_auth_token,
        certname                  => $trusted['certname'],
      }),
      require => File['/etc/vault.d'],
    }

    # Vault agent systemd service
    systemd::unit_file { 'vault-agent.service':
      content => epp('profile/vault/vault-agent.service.epp'),
      enable  => true,
      active  => true,
      require => File['/etc/vault.d/agent.hcl'],
    }

    # Create a fact to indicate Vault is available
    file { '/etc/facter/facts.d':
      ensure => directory,
      owner  => 'root',
      group  => 'root',
      mode   => '0755',
    }

    file { '/etc/facter/facts.d/vault.yaml':
      ensure  => file,
      owner   => 'root',
      group   => 'root',
      mode    => '0644',
      content => "---\nvault_available: true\nvault_addr: ${_vault_addr}\n",
      require => File['/etc/facter/facts.d'],
    }
  }
}
