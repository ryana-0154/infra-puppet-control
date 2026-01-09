# @summary Manages HashiCorp Vault for secrets management
#
# This profile deploys HashiCorp Vault as a Docker container for use as a
# secrets backend for Foreman ENC and other infrastructure services.
# Vault provides secure secret storage, dynamic credentials, and encryption
# as a service.
#
# @note Requirements
#   - Docker must be installed and running
#   - TLS certificates should be provided (from ACME or other source)
#
# @note Foreman Integration
#   After Vault is deployed and initialized:
#   1. Install foreman_vault plugin on Foreman server
#   2. Enable AppRole auth method in Vault
#   3. Create policy for Foreman with appropriate permissions
#   4. Configure AppRole with role_id and secret_id for Foreman
#   5. Add Vault connection in Foreman UI under Infrastructure > Vault Connections
#
# @param manage_vault
#   Whether to manage the Vault deployment
# @param vault_dir
#   Base directory for Vault configuration and data
# @param vault_image
#   Docker image for HashiCorp Vault
# @param api_port
#   Port for Vault API (default: 8200)
# @param cluster_port
#   Port for Vault cluster communication (default: 8201)
# @param storage_backend
#   Storage backend type: 'file' or 'raft' (default: 'file')
# @param raft_node_id
#   Node ID for Raft storage backend (required if storage_backend is 'raft')
# @param raft_cluster_members
#   Array of cluster member addresses for Raft (leader join)
# @param tls_enabled
#   Whether to enable TLS (strongly recommended for production)
# @param tls_cert_file
#   Path to TLS certificate file (within container)
# @param tls_key_file
#   Path to TLS private key file (within container)
# @param tls_cert_source
#   Source path for TLS certificate on host
# @param tls_key_source
#   Source path for TLS key on host
# @param ui_enabled
#   Whether to enable the Vault web UI
# @param api_addr
#   Full API address for Vault (used for client redirects)
# @param cluster_addr
#   Full cluster address for Vault (used in HA setups)
# @param log_level
#   Vault log level (trace, debug, info, warn, error)
# @param disable_mlock
#   Whether to disable mlock (required for some container runtimes)
# @param max_lease_ttl
#   Maximum lease TTL for secrets
# @param default_lease_ttl
#   Default lease TTL for secrets
# @param audit_log_enabled
#   Whether to enable file audit logging
# @param telemetry_enabled
#   Whether to enable Prometheus telemetry endpoint
# @param telemetry_port
#   Port for Prometheus metrics (default: 8200, same as API)
#
# @example Basic usage via Hiera (development)
#   profile::vault::manage_vault: true
#   profile::vault::tls_enabled: false
#   profile::vault::ui_enabled: true
#
# @example Production usage with TLS
#   profile::vault::manage_vault: true
#   profile::vault::tls_enabled: true
#   profile::vault::tls_cert_source: '/etc/letsencrypt/live/vault.example.com/fullchain.pem'
#   profile::vault::tls_key_source: '/etc/letsencrypt/live/vault.example.com/privkey.pem'
#   profile::vault::api_addr: 'https://vault.example.com:8200'
#   profile::vault::ui_enabled: true
#
# @example With Raft storage for HA
#   profile::vault::manage_vault: true
#   profile::vault::storage_backend: 'raft'
#   profile::vault::raft_node_id: 'vault-1'
#   profile::vault::raft_cluster_members:
#     - 'https://vault-2.example.com:8201'
#     - 'https://vault-3.example.com:8201'
#
class profile::vault (
  Boolean              $manage_vault           = false,
  Stdlib::Absolutepath $vault_dir              = '/opt/vault',
  String[1]            $vault_image            = 'hashicorp/vault:1.18',

  # Network configuration
  Integer[1,65535]     $api_port               = 8200,
  Integer[1,65535]     $cluster_port           = 8201,

  # Storage configuration
  Enum['file', 'raft'] $storage_backend        = 'file',
  Optional[String[1]]  $raft_node_id           = undef,
  Array[String[1]]     $raft_cluster_members   = [],

  # TLS configuration
  Boolean              $tls_enabled            = true,
  String[1]            $tls_cert_file          = '/vault/certs/cert.pem',
  String[1]            $tls_key_file           = '/vault/certs/key.pem',
  Optional[Stdlib::Absolutepath] $tls_cert_source = undef,
  Optional[Stdlib::Absolutepath] $tls_key_source  = undef,

  # Vault configuration
  Boolean              $ui_enabled             = true,
  Optional[String[1]]  $api_addr               = undef,
  Optional[String[1]]  $cluster_addr           = undef,
  Enum['trace', 'debug', 'info', 'warn', 'error'] $log_level = 'info',
  Boolean              $disable_mlock          = true,
  String[1]            $max_lease_ttl          = '768h',
  String[1]            $default_lease_ttl      = '768h',

  # Monitoring and audit
  Boolean              $audit_log_enabled      = true,
  Boolean              $telemetry_enabled      = false,
  Integer[1,65535]     $telemetry_port         = 8200,
) {
  # Multi-source parameter resolution (Foreman ENC -> Hiera -> Defaults)
  $_manage_vault = pick(
    getvar('vault_manage'),
    lookup('profile::vault::manage_vault', Optional[Boolean], 'first', undef),
    $manage_vault
  )

  # Validation
  if $_manage_vault {
    if $storage_backend == 'raft' and !$raft_node_id {
      fail('profile::vault: raft_node_id is required when storage_backend is raft')
    }
    if $tls_enabled and (!$tls_cert_source or !$tls_key_source) {
      fail('profile::vault: tls_cert_source and tls_key_source are required when tls_enabled is true')
    }
  }

  if $_manage_vault {
    # Determine protocol for addresses
    $_protocol = $tls_enabled ? {
      true    => 'https',
      default => 'http',
    }

    # Calculate API address if not provided
    $_api_addr = $api_addr ? {
      undef   => "${_protocol}://127.0.0.1:${api_port}",
      default => $api_addr,
    }

    # Calculate cluster address if not provided
    $_cluster_addr = $cluster_addr ? {
      undef   => "${_protocol}://127.0.0.1:${cluster_port}",
      default => $cluster_addr,
    }

    # Ensure Docker Compose v2 is installed
    ensure_packages(['docker-compose-plugin'])

    # Create Vault directory structure
    $vault_directories = [
      $vault_dir,
      "${vault_dir}/data",
      "${vault_dir}/config",
      "${vault_dir}/logs",
      "${vault_dir}/certs",
      "${vault_dir}/plugins",
    ]

    # Add raft directory if using raft storage
    $all_directories = $storage_backend ? {
      'raft'  => $vault_directories + ["${vault_dir}/raft"],
      default => $vault_directories,
    }

    file { $all_directories:
      ensure => directory,
      mode   => '0755',
      owner  => 'root',
      group  => 'root',
    }

    # Copy TLS certificates if provided
    if $tls_enabled {
      file { "${vault_dir}/certs/cert.pem":
        ensure  => file,
        source  => $tls_cert_source,
        mode    => '0644',
        owner   => 'root',
        group   => 'root',
        require => File["${vault_dir}/certs"],
      }

      file { "${vault_dir}/certs/key.pem":
        ensure  => file,
        source  => $tls_key_source,
        mode    => '0600',
        owner   => 'root',
        group   => 'root',
        require => File["${vault_dir}/certs"],
      }

      $tls_file_deps = [
        File["${vault_dir}/certs/cert.pem"],
        File["${vault_dir}/certs/key.pem"],
      ]
    } else {
      $tls_file_deps = []
    }

    # Vault server configuration
    file { "${vault_dir}/config/vault.hcl":
      ensure  => file,
      mode    => '0644',
      owner   => 'root',
      group   => 'root',
      content => epp('profile/vault/vault.hcl.epp', {
          vault_dir            => $vault_dir,
          api_port             => $api_port,
          cluster_port         => $cluster_port,
          storage_backend      => $storage_backend,
          raft_node_id         => $raft_node_id,
          raft_cluster_members => $raft_cluster_members,
          tls_enabled          => $tls_enabled,
          tls_cert_file        => $tls_cert_file,
          tls_key_file         => $tls_key_file,
          ui_enabled           => $ui_enabled,
          api_addr             => $_api_addr,
          cluster_addr         => $_cluster_addr,
          log_level            => $log_level,
          disable_mlock        => $disable_mlock,
          max_lease_ttl        => $max_lease_ttl,
          default_lease_ttl    => $default_lease_ttl,
          telemetry_enabled    => $telemetry_enabled,
          telemetry_port       => $telemetry_port,
      }),
      require => File["${vault_dir}/config"],
    }

    # Docker Compose configuration
    file { "${vault_dir}/docker-compose.yaml":
      ensure  => file,
      mode    => '0644',
      owner   => 'root',
      group   => 'root',
      content => epp('profile/vault/docker-compose.yaml.epp', {
          vault_dir       => $vault_dir,
          vault_image     => $vault_image,
          api_port        => $api_port,
          cluster_port    => $cluster_port,
          storage_backend => $storage_backend,
          tls_enabled     => $tls_enabled,
          disable_mlock   => $disable_mlock,
      }),
      require => File[$vault_dir],
    }

    # Environment file for Docker Compose
    file { "${vault_dir}/.env":
      ensure  => file,
      mode    => '0600',
      owner   => 'root',
      group   => 'root',
      content => epp('profile/vault/.env.epp', {
          vault_dir   => $vault_dir,
          api_addr    => $_api_addr,
          log_level   => $log_level,
          tls_enabled => $tls_enabled,
      }),
      require => File[$vault_dir],
    }

    # Ensure docker-compose stack is running
    exec { 'start-vault':
      command => 'docker compose up -d',
      cwd     => $vault_dir,
      path    => ['/usr/bin', '/usr/local/bin', '/usr/sbin', '/bin', '/sbin', '/snap/bin'],
      unless  => "docker ps --format '{{.Names}}' | grep -q '^vault$'",
      require => [
        File["${vault_dir}/docker-compose.yaml"],
        File["${vault_dir}/.env"],
        File["${vault_dir}/config/vault.hcl"],
      ] + $tls_file_deps,
    }

    # Restart container when configuration changes
    exec { 'restart-vault':
      command     => 'docker compose up -d --force-recreate',
      cwd         => $vault_dir,
      path        => ['/usr/bin', '/usr/local/bin', '/usr/sbin', '/bin', '/sbin', '/snap/bin'],
      refreshonly => true,
      subscribe   => [
        File["${vault_dir}/docker-compose.yaml"],
        File["${vault_dir}/.env"],
        File["${vault_dir}/config/vault.hcl"],
      ],
    }

    # Create helper script for Vault CLI operations
    file { "${vault_dir}/vault-cli.sh":
      ensure  => file,
      mode    => '0755',
      owner   => 'root',
      group   => 'root',
      content => epp('profile/vault/vault-cli.sh.epp', {
          vault_dir   => $vault_dir,
          api_addr    => $_api_addr,
          tls_enabled => $tls_enabled,
      }),
      require => File[$vault_dir],
    }

    # Create Foreman integration helper script
    file { "${vault_dir}/foreman-setup.sh":
      ensure  => file,
      mode    => '0755',
      owner   => 'root',
      group   => 'root',
      content => epp('profile/vault/foreman-setup.sh.epp', {
          vault_dir   => $vault_dir,
          api_addr    => $_api_addr,
          tls_enabled => $tls_enabled,
      }),
      require => File[$vault_dir],
    }
  }
}
