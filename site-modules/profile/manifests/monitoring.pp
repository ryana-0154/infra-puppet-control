# @summary Manages monitoring infrastructure
#
# This profile sets up monitoring directories and related infrastructure.
#
# @note Requirements
#   - Docker must be installed and running
#   - This profile will ensure docker-compose-plugin (v2) is installed
#
# @param manage_monitoring
#   Whether to manage monitoring configuration
# @param monitoring_dir
#   Base directory for monitoring tools and data
# @param monitoring_dir_owner
#   Owner of the monitoring directory
# @param monitoring_dir_group
#   Group of the monitoring directory
# @param monitoring_dir_mode
#   File mode for the monitoring directory
# @param monitoring_ip
#   IP address services will bind to
# @param victoriametrics_port
#   Port for VictoriaMetrics web interface
# @param grafana_port
#   Port for Grafana web interface
# @param blackbox_port
#   Port for Blackbox Exporter
# @param pihole_exporter_port
#   Port for PiHole Exporter
# @param enable_victoriametrics
#   Whether to enable VictoriaMetrics service
# @param enable_grafana
#   Whether to enable Grafana service
# @param enable_loki
#   Whether to enable Loki service
# @param enable_promtail
#   Whether to enable Promtail service
# @param enable_pihole_exporter
#   Whether to enable PiHole Exporter service
# @param enable_blackbox
#   Whether to enable Blackbox Exporter service
# @param enable_node_exporter
#   Whether to enable Node Exporter service
# @param enable_wg_portal
#   Whether to enable WireGuard Portal service
# @param enable_wireguard_exporter
#   Whether to enable WireGuard Prometheus exporter
# @param enable_unbound_exporter
#   Whether to enable Unbound Prometheus exporter
# @param enable_authelia
#   Whether to enable Authelia SSO
# @param enable_nginx_proxy
#   Whether to enable Nginx reverse proxy for SSO
# @param enable_redis
#   Whether to enable Redis for Authelia session storage
# @param victoriametrics_image
#   Docker image for VictoriaMetrics
# @param grafana_image
#   Docker image for Grafana
# @param loki_image
#   Docker image for Loki
# @param promtail_image
#   Docker image for Promtail
# @param pihole_exporter_image
#   Docker image for PiHole Exporter
# @param blackbox_image
#   Docker image for Blackbox Exporter
# @param node_exporter_image
#   Docker image for Node Exporter
# @param wg_portal_image
#   Docker image for WireGuard Portal
# @param wireguard_exporter_image
#   Docker image for WireGuard Prometheus exporter
# @param unbound_exporter_image
#   Docker image for Unbound Prometheus exporter
# @param authelia_image
#   Docker image for Authelia
# @param nginx_image
#   Docker image for Nginx
# @param redis_image
#   Docker image for Redis
# @param domain_name
#   Domain name for SSO (e.g., example.com)
# @param enable_ssl
#   Whether to enable SSL/TLS with Let's Encrypt
# @param letsencrypt_email
#   Email address for Let's Encrypt certificate notifications (required if enable_ssl is true)
# @param certbot_image
#   Docker image for Certbot
# @param authelia_jwt_secret
#   JWT secret for Authelia (should be encrypted with eyaml)
# @param authelia_session_secret
#   Session secret for Authelia (should be encrypted with eyaml)
# @param authelia_storage_encryption_key
#   Storage encryption key for Authelia (should be encrypted with eyaml)
# @param sso_users
#   Hash of SSO users with encrypted passwords
# @param grafana_oidc_secret
#   OIDC client secret for Grafana integration (should be encrypted with eyaml)
# @param oidc_private_key
#   Private key for OIDC JWT signing (should be encrypted with eyaml)
# @param pihole_hostname
#   Hostname/IP of PiHole instance
# @param pihole_port
#   Port of PiHole instance
# @param pihole_protocol
#   Protocol to connect to PiHole (http/https)
# @param pihole_interval
#   Interval for PiHole metrics collection
# @param grafana_admin_password
#   Admin password for Grafana (should be encrypted with eyaml)
# @param pihole_password
#   Password for PiHole API access (should be encrypted with eyaml)
# @param pihole_api_token
#   API token for PiHole access (should be encrypted with eyaml)
# @param enable_external_dashboards
#   Whether to provision Grafana dashboards from an external Git repository
# @param dashboard_repo_url
#   Git repository URL containing Grafana dashboards (required if enable_external_dashboards is true)
# @param dashboard_repo_revision
#   Git branch, tag, or commit to checkout for dashboards repository
# @param enable_embedded_dashboards
#   Whether to keep provisioning the embedded Loki dashboard (can be used alongside external dashboards)
# @param dashboard_auto_update
#   Whether to automatically pull latest dashboard changes on each Puppet run
# @param grafana_plugins
#   Array of Grafana plugin IDs to install (e.g., ['grafana-piechart-panel', 'grafana-clock-panel'])
# @param wireguard_config_path
#   Path to WireGuard configuration directory for the exporter
# @param unbound_host
#   Hostname/IP where Unbound is running
# @param unbound_control_port
#   Port for Unbound control interface
#
# @example Basic usage
#   include profile::monitoring
#
# @example With Grafana plugins via Hiera
#   profile::monitoring::grafana_plugins:
#     - grafana-piechart-panel
#     - grafana-clock-panel
#
# @example With custom directory via Hiera
#   profile::monitoring::monitoring_dir: '/opt/custom-monitoring'
#
class profile::monitoring (
  Boolean                        $manage_monitoring         = true,
  Stdlib::Absolutepath           $monitoring_dir            = '/opt/monitoring',
  String[1]                      $monitoring_dir_owner      = 'root',
  String[1]                      $monitoring_dir_group      = 'root',
  String[4,4]                    $monitoring_dir_mode       = '0755',

  # Network configuration
  String[1]                      $monitoring_ip             = '10.10.10.1',

  # Service ports
  Integer[1,65535]               $victoriametrics_port      = 8428,
  Integer[1,65535]               $grafana_port              = 3000,
  Integer[1,65535]               $blackbox_port             = 9115,
  Integer[1,65535]               $pihole_exporter_port      = 9617,
  Integer[1,65535]               $wireguard_exporter_port   = 9586,
  Integer[1,65535]               $unbound_exporter_port     = 9167,

  # Service enable/disable flags
  Boolean                        $enable_victoriametrics    = true,
  Boolean                        $enable_grafana            = true,
  Boolean                        $enable_loki               = true,
  Boolean                        $enable_promtail           = true,
  Boolean                        $enable_pihole_exporter    = true,
  Boolean                        $enable_blackbox           = true,
  Boolean                        $enable_node_exporter      = true,
  Boolean                        $enable_wg_portal          = true,
  Boolean                        $enable_wireguard_exporter = true,
  Boolean                        $enable_unbound_exporter   = true,

  # SSO/Authentication
  Boolean                        $enable_authelia           = false,
  Boolean                        $enable_nginx_proxy        = false,
  Boolean                        $enable_redis              = false,

  # Image versions
  String[1]                      $victoriametrics_image     = 'victoriametrics/victoria-metrics:latest',
  String[1]                      $grafana_image             = 'grafana/grafana:latest',
  String[1]                      $loki_image                = 'grafana/loki:3.1.1',
  String[1]                      $promtail_image            = 'grafana/promtail:3.1.1',
  String[1]                      $pihole_exporter_image     = 'ekofr/pihole-exporter:latest',
  String[1]                      $blackbox_image            = 'prom/blackbox-exporter:latest',
  String[1]                      $node_exporter_image       = 'quay.io/prometheus/node-exporter:latest',
  String[1]                      $wg_portal_image           = 'wgportal/wg-portal:v2',
  String[1]                      $wireguard_exporter_image  = 'mindflavor/prometheus-wireguard-exporter:latest',
  String[1]                      $unbound_exporter_image    = 'cyb3rjak3/unbound-exporter:latest',

  # SSO images
  String[1]                      $authelia_image            = 'authelia/authelia:4.38',
  String[1]                      $nginx_image               = 'nginx:1.25-alpine',
  String[1]                      $redis_image               = 'redis:7-alpine',

  # SSO configuration
  Optional[String[1]]            $domain_name               = undef,

  # SSL/TLS configuration
  Boolean                        $enable_ssl                = false,
  Optional[String[1]]            $letsencrypt_email         = undef,
  String[1]                      $certbot_image             = 'certbot/certbot:latest',

  Optional[String[1]]            $authelia_jwt_secret       = undef,
  Optional[String[1]]            $authelia_session_secret   = undef,
  Optional[String[1]]            $authelia_storage_encryption_key = undef,
  Hash                           $sso_users                 = {},
  Optional[String[1]]            $grafana_oidc_secret       = undef,
  Optional[String[1]]            $oidc_private_key          = undef,

  # PiHole configuration
  String[1]                      $pihole_hostname           = '10.10.10.1',
  Integer[1,65535]               $pihole_port               = 80,
  String[1]                      $pihole_protocol           = 'http',
  String[1]                      $pihole_interval           = '30s',

  # Secrets (should be encrypted with eyaml)
  Optional[String[1]]            $grafana_admin_password    = undef,
  Optional[String[1]]            $pihole_password           = undef,
  Optional[String[1]]            $pihole_api_token          = undef,

  # Grafana Dashboard configuration
  Boolean                        $enable_external_dashboards = false,
  Optional[String[1]]            $dashboard_repo_url        = undef,
  String[1]                      $dashboard_repo_revision   = 'main',
  Boolean                        $enable_embedded_dashboards = true,
  Boolean                        $dashboard_auto_update     = false,
  Array[String[1]]               $grafana_plugins           = [],

  # WireGuard exporter configuration
  Stdlib::Absolutepath           $wireguard_config_path     = '/etc/wireguard',

  # Unbound exporter configuration
  String[1]                      $unbound_host              = '127.0.0.1',
  Integer[1,65535]               $unbound_control_port      = 8953,

  # Grafana Cloud integration
  Boolean                        $enable_grafana_cloud      = false,
  Optional[String[1]]                           $grafana_cloud_metrics_url = undef,
  Optional[String[1]]                           $grafana_cloud_logs_url    = undef,
  Optional[String[1]]                           $grafana_cloud_metrics_username = undef,
  Optional[String[1]]                           $grafana_cloud_logs_username = undef,
  Optional[Variant[String[1], Sensitive[String[1]]]] $grafana_cloud_metrics_api_key = undef,
  Optional[Variant[String[1], Sensitive[String[1]]]] $grafana_cloud_logs_api_key = undef,

  # Agent selection
  Enum['alloy', 'victoriametrics'] $metrics_agent = 'victoriametrics',
  String[1]                      $alloy_image              = 'grafana/alloy:latest',
  Integer[1,65535]               $alloy_http_port          = 12345,
) {
  # Validate SSO parameters when Authelia is enabled
  if $enable_authelia {
    if !$domain_name {
      fail('profile::monitoring: domain_name is required when enable_authelia is true')
    }
    if !$authelia_jwt_secret {
      fail('profile::monitoring: authelia_jwt_secret is required when enable_authelia is true')
    }
    if !$authelia_session_secret {
      fail('profile::monitoring: authelia_session_secret is required when enable_authelia is true')
    }
    if !$authelia_storage_encryption_key {
      fail('profile::monitoring: authelia_storage_encryption_key is required when enable_authelia is true')
    }
    if $sso_users.empty {
      fail('profile::monitoring: sso_users hash cannot be empty when enable_authelia is true')
    }
  }

  # Validate nginx proxy parameters
  if $enable_nginx_proxy and !$domain_name {
    fail('profile::monitoring: domain_name is required when enable_nginx_proxy is true')
  }

  # Validate Grafana OIDC integration
  if $enable_authelia and $enable_grafana and !$grafana_oidc_secret {
    fail('profile::monitoring: grafana_oidc_secret is required when both enable_authelia and enable_grafana are true')
  }

  # Validate external dashboard parameters
  if $enable_external_dashboards and !$dashboard_repo_url {
    fail('profile::monitoring: dashboard_repo_url is required when enable_external_dashboards is true')
  }

  # Validate SSL parameters
  if $enable_ssl and !$letsencrypt_email {
    fail('profile::monitoring: letsencrypt_email is required when enable_ssl is true')
  }

  if $enable_ssl and !$domain_name {
    fail('profile::monitoring: domain_name is required when enable_ssl is true')
  }

  # Multi-source parameter resolution (Foreman ENC → Hiera → Defaults)
  # This allows configuration via Foreman Host/Hostgroup Parameters
  # Check both naming conventions: profile::monitoring::X and monitoring_X
  $_enable_grafana_cloud = pick(
    getvar('profile::monitoring::enable_grafana_cloud'),
    getvar('monitoring_enable_grafana_cloud'),
    lookup('profile::monitoring::enable_grafana_cloud', Optional[Boolean], 'first', undef),
    $enable_grafana_cloud
  )

  $_metrics_agent = pick(
    getvar('profile::monitoring::metrics_agent'),
    getvar('monitoring_metrics_agent'),
    lookup('profile::monitoring::metrics_agent', Optional[String], 'first', undef),
    $metrics_agent
  )

  # Check both naming conventions for optional URL parameters
  $_grafana_cloud_metrics_url_enc = pick(
    getvar('profile::monitoring::grafana_cloud_metrics_url'),
    getvar('monitoring_grafana_cloud_metrics_url'),
    undef
  )
  $_grafana_cloud_metrics_url_hiera = lookup('profile::monitoring::grafana_cloud_metrics_url', Optional[String], 'first', undef)
  $_grafana_cloud_metrics_url = $_grafana_cloud_metrics_url_enc ? {
    undef   => $_grafana_cloud_metrics_url_hiera ? {
      undef   => $grafana_cloud_metrics_url,
      default => $_grafana_cloud_metrics_url_hiera,
    },
    default => $_grafana_cloud_metrics_url_enc,
  }

  $_grafana_cloud_logs_url_enc = pick(
    getvar('profile::monitoring::grafana_cloud_logs_url'),
    getvar('monitoring_grafana_cloud_logs_url'),
    undef
  )
  $_grafana_cloud_logs_url_hiera = lookup('profile::monitoring::grafana_cloud_logs_url', Optional[String], 'first', undef)
  $_grafana_cloud_logs_url = $_grafana_cloud_logs_url_enc ? {
    undef   => $_grafana_cloud_logs_url_hiera ? {
      undef   => $grafana_cloud_logs_url,
      default => $_grafana_cloud_logs_url_hiera,
    },
    default => $_grafana_cloud_logs_url_enc,
  }

  $_grafana_cloud_metrics_username_enc = pick(
    getvar('profile::monitoring::grafana_cloud_metrics_username'),
    getvar('monitoring_grafana_cloud_metrics_username'),
    undef
  )
  $_grafana_cloud_metrics_username_hiera = lookup('profile::monitoring::grafana_cloud_metrics_username', Optional[String], 'first', undef)
  $_grafana_cloud_metrics_username = $_grafana_cloud_metrics_username_enc ? {
    undef   => $_grafana_cloud_metrics_username_hiera ? {
      undef   => $grafana_cloud_metrics_username,
      default => $_grafana_cloud_metrics_username_hiera,
    },
    default => $_grafana_cloud_metrics_username_enc,
  }

  $_grafana_cloud_logs_username_enc = pick(
    getvar('profile::monitoring::grafana_cloud_logs_username'),
    getvar('monitoring_grafana_cloud_logs_username'),
    undef
  )
  $_grafana_cloud_logs_username_hiera = lookup('profile::monitoring::grafana_cloud_logs_username', Optional[String], 'first', undef)
  $_grafana_cloud_logs_username = $_grafana_cloud_logs_username_enc ? {
    undef   => $_grafana_cloud_logs_username_hiera ? {
      undef   => $grafana_cloud_logs_username,
      default => $_grafana_cloud_logs_username_hiera,
    },
    default => $_grafana_cloud_logs_username_enc,
  }

  # Sensitive parameters need special handling - check both naming conventions
  # Wrap with Sensitive() if it's a plain string
  $_grafana_cloud_metrics_api_key_raw = pick(
    getvar('profile::monitoring::grafana_cloud_metrics_api_key'),
    getvar('monitoring_grafana_cloud_metrics_api_key'),
    undef
  )
  $_grafana_cloud_metrics_api_key_hiera = lookup('profile::monitoring::grafana_cloud_metrics_api_key', Optional[Variant[String, Sensitive[String]]], 'first', undef)
  # Wrap Hiera value with Sensitive() if it's a plain string
  $_grafana_cloud_metrics_api_key_hiera_wrapped = $_grafana_cloud_metrics_api_key_hiera ? {
    Sensitive => $_grafana_cloud_metrics_api_key_hiera,
    String    => Sensitive($_grafana_cloud_metrics_api_key_hiera),
    default   => undef,
  }
  $_grafana_cloud_metrics_api_key_param = $grafana_cloud_metrics_api_key ? {
    Sensitive => $grafana_cloud_metrics_api_key,
    String    => Sensitive($grafana_cloud_metrics_api_key),
    default   => undef,
  }
  $_grafana_cloud_metrics_api_key = $_grafana_cloud_metrics_api_key_raw ? {
    undef   => $_grafana_cloud_metrics_api_key_hiera_wrapped ? {
      undef   => $_grafana_cloud_metrics_api_key_param,
      default => $_grafana_cloud_metrics_api_key_hiera_wrapped,
    },
    default => Sensitive($_grafana_cloud_metrics_api_key_raw),
  }

  $_grafana_cloud_logs_api_key_raw = pick(
    getvar('profile::monitoring::grafana_cloud_logs_api_key'),
    getvar('monitoring_grafana_cloud_logs_api_key'),
    undef
  )
  $_grafana_cloud_logs_api_key_hiera = lookup('profile::monitoring::grafana_cloud_logs_api_key', Optional[Variant[String, Sensitive[String]]], 'first', undef)
  # Wrap Hiera value with Sensitive() if it's a plain string
  $_grafana_cloud_logs_api_key_hiera_wrapped = $_grafana_cloud_logs_api_key_hiera ? {
    Sensitive => $_grafana_cloud_logs_api_key_hiera,
    String    => Sensitive($_grafana_cloud_logs_api_key_hiera),
    default   => undef,
  }
  $_grafana_cloud_logs_api_key_param = $grafana_cloud_logs_api_key ? {
    Sensitive => $grafana_cloud_logs_api_key,
    String    => Sensitive($grafana_cloud_logs_api_key),
    default   => undef,
  }
  $_grafana_cloud_logs_api_key = $_grafana_cloud_logs_api_key_raw ? {
    undef   => $_grafana_cloud_logs_api_key_hiera_wrapped ? {
      undef   => $_grafana_cloud_logs_api_key_param,
      default => $_grafana_cloud_logs_api_key_hiera_wrapped,
    },
    default => Sensitive($_grafana_cloud_logs_api_key_raw),
  }

  # Validate Grafana Cloud parameters
  if $_enable_grafana_cloud {
    if !$_grafana_cloud_metrics_url or !$_grafana_cloud_logs_url or
      !$_grafana_cloud_metrics_username or !$_grafana_cloud_logs_username or
      !$_grafana_cloud_metrics_api_key or !$_grafana_cloud_logs_api_key {
      fail('profile::monitoring: All grafana_cloud_* parameters required when enable_grafana_cloud is true')
    }
  }

  if $manage_monitoring {
    # Set template variables for docker-compose (ERB templates need these in scope)
    $enable_grafana_cloud_resolved = $_enable_grafana_cloud
    $metrics_agent_resolved = $_metrics_agent

    # Ensure Docker Compose v2 is installed
    ensure_packages(['docker-compose-plugin'])

    # Ensure git is installed for external dashboard repos
    if $enable_external_dashboards {
      ensure_packages(['git'])
    }

    # Ensure the monitoring directory exists
    file { $monitoring_dir:
      ensure => directory,
      group  => $monitoring_dir_group,
      mode   => $monitoring_dir_mode,
      owner  => $monitoring_dir_owner,
    }

    file { "${monitoring_dir}/docker-compose.yaml":
      ensure  => file,
      content => template('profile/monitoring/docker-compose.yaml.erb'),
      group   => $monitoring_dir_group,
      mode    => '0644',
      owner   => $monitoring_dir_owner,
      require => File[$monitoring_dir],
    }

    # Create configuration files for services
    if $enable_victoriametrics {
      file { "${monitoring_dir}/victoriametrics-scrape.yaml":
        ensure  => file,
        content => template('profile/monitoring/victoriametrics-scrape.yaml.erb'),
        group   => $monitoring_dir_group,
        mode    => '0644',
        owner   => $monitoring_dir_owner,
        require => File[$monitoring_dir],
      }
    }

    if $enable_loki {
      file { "${monitoring_dir}/loki-config.yaml":
        ensure  => file,
        content => template('profile/monitoring/loki-config.yaml.erb'),
        group   => $monitoring_dir_group,
        mode    => '0644',
        owner   => $monitoring_dir_owner,
        require => File[$monitoring_dir],
      }
    }

    if $enable_promtail {
      # ERB templates need variables in scope - use unique names to avoid conflicts
      $promtail_enable_grafana_cloud        = $_enable_grafana_cloud
      $promtail_grafana_cloud_logs_url      = $_grafana_cloud_logs_url
      $promtail_grafana_cloud_logs_username = $_grafana_cloud_logs_username
      $promtail_grafana_cloud_logs_api_key  = $_grafana_cloud_logs_api_key
      $promtail_enable_loki                 = $enable_loki
      $promtail_monitoring_ip               = $monitoring_ip
      $promtail_enable_prometheus           = $enable_victoriametrics
      $promtail_enable_grafana              = $enable_grafana
      $promtail_enable_blackbox             = $enable_blackbox
      $promtail_enable_node_exporter        = $enable_node_exporter
      $promtail_enable_pihole_exporter      = $enable_pihole_exporter
      $promtail_enable_nginx_proxy          = $enable_nginx_proxy
      $promtail_enable_authelia             = $enable_authelia
      $promtail_enable_redis                = $enable_redis
      $promtail_enable_promtail             = $enable_promtail
      $promtail_facts                       = $facts

      file { "${monitoring_dir}/promtail-config.yaml":
        ensure  => file,
        content => template('profile/monitoring/promtail-config.yaml.erb'),
        group   => $monitoring_dir_group,
        mode    => '0644',
        owner   => $monitoring_dir_owner,
        require => File[$monitoring_dir],
      }
    }

    if $enable_blackbox {
      file { "${monitoring_dir}/blackbox.yaml":
        ensure  => file,
        content => template('profile/monitoring/blackbox.yaml.erb'),
        group   => $monitoring_dir_group,
        mode    => '0644',
        owner   => $monitoring_dir_owner,
        require => File[$monitoring_dir],
      }
    }

    # Create Grafana Alloy configuration
    if $_enable_grafana_cloud and $_metrics_agent == 'alloy' {
      file { "${monitoring_dir}/alloy-config.alloy":
        ensure  => file,
        content => epp('profile/monitoring/alloy-config.alloy.epp', {
          enable_node_exporter           => $enable_node_exporter,
          enable_blackbox                => $enable_blackbox,
          enable_pihole_exporter         => $enable_pihole_exporter,
          enable_wireguard_exporter      => $enable_wireguard_exporter,
          enable_unbound_exporter        => $enable_unbound_exporter,
          monitoring_ip                  => $monitoring_ip,
          blackbox_port                  => $blackbox_port,
          pihole_exporter_port           => $pihole_exporter_port,
          wireguard_exporter_port        => $wireguard_exporter_port,
          unbound_exporter_port          => $unbound_exporter_port,
          grafana_cloud_metrics_url      => $_grafana_cloud_metrics_url,
          grafana_cloud_metrics_username => $_grafana_cloud_metrics_username,
          grafana_cloud_metrics_api_key  => $_grafana_cloud_metrics_api_key,
          grafana_cloud_logs_url         => $_grafana_cloud_logs_url,
          grafana_cloud_logs_username    => $_grafana_cloud_logs_username,
          grafana_cloud_logs_api_key     => $_grafana_cloud_logs_api_key,
          node_facts                     => $facts,
        }),
        group   => $monitoring_dir_group,
        mode    => '0644',
        owner   => $monitoring_dir_owner,
        require => File[$monitoring_dir],
      }
    }

    # Create Grafana provisioning configuration
    if $enable_grafana {
      file { "${monitoring_dir}/provisioning":
        ensure  => directory,
        group   => $monitoring_dir_group,
        mode    => '0755',
        owner   => $monitoring_dir_owner,
        require => File[$monitoring_dir],
      }

      file { "${monitoring_dir}/provisioning/datasources":
        ensure  => directory,
        group   => $monitoring_dir_group,
        mode    => '0755',
        owner   => $monitoring_dir_owner,
        require => File["${monitoring_dir}/provisioning"],
      }

      file { "${monitoring_dir}/provisioning/datasources/loki.yaml":
        ensure  => file,
        content => template('profile/monitoring/provisioning/datasources/loki.yaml.erb'),
        group   => $monitoring_dir_group,
        mode    => '0644',
        owner   => $monitoring_dir_owner,
        require => File["${monitoring_dir}/provisioning/datasources"],
      }

      # Dashboard provisioning
      file { "${monitoring_dir}/provisioning/dashboards":
        ensure  => directory,
        group   => $monitoring_dir_group,
        mode    => '0755',
        owner   => $monitoring_dir_owner,
        require => File["${monitoring_dir}/provisioning"],
      }

      # Clone external dashboards repository if enabled
      if $enable_external_dashboards {
        $dashboard_repo_ensure = $dashboard_auto_update ? {
          true    => 'latest',
          default => 'present',
        }

        vcsrepo { "${monitoring_dir}/dashboards-external":
          ensure   => $dashboard_repo_ensure,
          provider => 'git',
          source   => $dashboard_repo_url,
          revision => $dashboard_repo_revision,
          require  => File[$monitoring_dir],
        }
      }

      file { "${monitoring_dir}/provisioning/dashboards/dashboard-provider.yaml":
        ensure  => file,
        content => epp('profile/monitoring/provisioning/dashboards/dashboard-provider.yaml.epp', {
          enable_embedded_dashboards => $enable_embedded_dashboards,
          enable_external_dashboards => $enable_external_dashboards,
          monitoring_dir             => $monitoring_dir,
        }),
        group   => $monitoring_dir_group,
        mode    => '0644',
        owner   => $monitoring_dir_owner,
        require => File["${monitoring_dir}/provisioning/dashboards"],
      }

      if $enable_embedded_dashboards {
        file { "${monitoring_dir}/provisioning/dashboards/loki-logs-overview.json":
          ensure  => file,
          content => template('profile/monitoring/provisioning/dashboards/loki-logs-overview.json.erb'),
          group   => $monitoring_dir_group,
          mode    => '0644',
          owner   => $monitoring_dir_owner,
          require => File["${monitoring_dir}/provisioning/dashboards"],
        }
      }
    }

    # Create secrets directory if any secrets are defined
    if $grafana_admin_password {
      file { "${monitoring_dir}/secrets":
        ensure => directory,
        group  => $monitoring_dir_group,
        mode   => '0755',
        owner  => $monitoring_dir_owner,
      }

      file { "${monitoring_dir}/secrets/grafana_admin_password":
        ensure  => file,
        content => $grafana_admin_password,
        group   => $monitoring_dir_group,
        mode    => '0644',
        owner   => $monitoring_dir_owner,
        require => File["${monitoring_dir}/secrets"],
      }
    }

    # Create SSO configuration files
    if $enable_authelia {
      file { "${monitoring_dir}/authelia-config.yaml":
        ensure  => file,
        content => template('profile/monitoring/authelia-config.yaml.erb'),
        group   => $monitoring_dir_group,
        mode    => '0644',
        owner   => $monitoring_dir_owner,
        require => File[$monitoring_dir],
      }

      file { "${monitoring_dir}/authelia-users.yaml":
        ensure  => file,
        content => template('profile/monitoring/authelia-users.yaml.erb'),
        group   => $monitoring_dir_group,
        mode    => '0600',
        owner   => $monitoring_dir_owner,
        require => File[$monitoring_dir],
      }
    }

    if $enable_nginx_proxy {
      file { "${monitoring_dir}/nginx.conf":
        ensure  => file,
        content => template('profile/monitoring/nginx.conf.erb'),
        group   => $monitoring_dir_group,
        mode    => '0644',
        owner   => $monitoring_dir_owner,
        require => File[$monitoring_dir],
      }

      # Deploy SSL initialization script
      if $enable_ssl {
        file { "${monitoring_dir}/init-ssl.sh":
          ensure  => file,
          content => template('profile/monitoring/init-ssl.sh.erb'),
          group   => $monitoring_dir_group,
          mode    => '0755',
          owner   => $monitoring_dir_owner,
          require => File[$monitoring_dir],
        }
      }
    }

    # Ensure docker-compose stack is running
    exec { 'start-monitoring-stack':
      command => 'docker compose up -d',
      cwd     => $monitoring_dir,
      path    => ['/usr/bin', '/usr/local/bin', '/usr/sbin', '/bin', '/sbin', '/snap/bin'],
      unless  => 'docker compose ps -q 2>/dev/null | grep -q .',
      require => File["${monitoring_dir}/docker-compose.yaml"],
    }

    # Restart containers when configuration changes
    # Build subscribe array based on enabled services
    $base_subscribe = [File["${monitoring_dir}/docker-compose.yaml"]]
    $victoriametrics_subscribe = $enable_victoriametrics ? {
      true    => [File["${monitoring_dir}/victoriametrics-scrape.yaml"]],
      default => [],
    }
    $loki_subscribe = $enable_loki ? {
      true    => [File["${monitoring_dir}/loki-config.yaml"]],
      default => [],
    }
    $promtail_subscribe = $enable_promtail ? {
      true    => [File["${monitoring_dir}/promtail-config.yaml"]],
      default => [],
    }
    $blackbox_subscribe = $enable_blackbox ? {
      true    => [File["${monitoring_dir}/blackbox.yaml"]],
      default => [],
    }
    $grafana_subscribe = $enable_grafana ? {
      true    => [
        File["${monitoring_dir}/provisioning/datasources/loki.yaml"],
        File["${monitoring_dir}/provisioning/dashboards/dashboard-provider.yaml"],
      ],
      default => [],
    }
    $authelia_subscribe = $enable_authelia ? {
      true    => [
        File["${monitoring_dir}/authelia-config.yaml"],
        File["${monitoring_dir}/authelia-users.yaml"],
      ],
      default => [],
    }
    $nginx_subscribe = $enable_nginx_proxy ? {
      true    => [File["${monitoring_dir}/nginx.conf"]],
      default => [],
    }
    $external_dashboards_subscribe = $enable_external_dashboards ? {
      true    => [Vcsrepo["${monitoring_dir}/dashboards-external"]],
      default => [],
    }
    $alloy_subscribe = $_enable_grafana_cloud ? {
      true    => [File["${monitoring_dir}/alloy-config.alloy"]],
      default => [],
    }

    $all_subscribe = $base_subscribe + $victoriametrics_subscribe + $loki_subscribe + $promtail_subscribe + $blackbox_subscribe + $grafana_subscribe + $authelia_subscribe + $nginx_subscribe + $external_dashboards_subscribe + $alloy_subscribe

    exec { 'restart-monitoring-stack':
      command     => 'docker compose up -d --force-recreate --remove-orphans',
      cwd         => $monitoring_dir,
      path        => ['/usr/bin', '/usr/local/bin', '/usr/sbin', '/bin', '/sbin', '/snap/bin'],
      refreshonly => true,
      subscribe   => $all_subscribe,
    }
  }
}
