# @summary Manages monitoring infrastructure
#
# This profile sets up monitoring directories and related infrastructure.
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
# @param prometheus_port
#   Port for Prometheus web interface
# @param grafana_port
#   Port for Grafana web interface
# @param blackbox_port
#   Port for Blackbox Exporter
# @param pihole_exporter_port
#   Port for PiHole Exporter
# @param enable_prometheus
#   Whether to enable Prometheus service
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
# @param enable_authelia
#   Whether to enable Authelia SSO
# @param enable_nginx_proxy
#   Whether to enable Nginx reverse proxy for SSO
# @param enable_redis
#   Whether to enable Redis for Authelia session storage
# @param prometheus_image
#   Docker image for Prometheus
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
# @param authelia_image
#   Docker image for Authelia
# @param nginx_image
#   Docker image for Nginx
# @param redis_image
#   Docker image for Redis
# @param domain_name
#   Domain name for SSO (e.g., example.com)
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
#
# @example Basic usage
#   include profile::monitoring
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
  Integer[1,65535]               $prometheus_port           = 9090,
  Integer[1,65535]               $grafana_port              = 3000,
  Integer[1,65535]               $blackbox_port             = 9115,
  Integer[1,65535]               $pihole_exporter_port      = 9617,

  # Service enable/disable flags
  Boolean                        $enable_prometheus         = true,
  Boolean                        $enable_grafana            = true,
  Boolean                        $enable_loki               = true,
  Boolean                        $enable_promtail           = true,
  Boolean                        $enable_pihole_exporter    = true,
  Boolean                        $enable_blackbox           = true,
  Boolean                        $enable_node_exporter      = true,
  Boolean                        $enable_wg_portal          = true,

  # SSO/Authentication
  Boolean                        $enable_authelia           = false,
  Boolean                        $enable_nginx_proxy        = false,
  Boolean                        $enable_redis              = false,

  # Image versions
  String[1]                      $prometheus_image          = 'prom/prometheus:latest',
  String[1]                      $grafana_image             = 'grafana/grafana:latest',
  String[1]                      $loki_image                = 'grafana/loki:3.1.1',
  String[1]                      $promtail_image            = 'grafana/promtail:3.1.1',
  String[1]                      $pihole_exporter_image     = 'ekofr/pihole-exporter:latest',
  String[1]                      $blackbox_image            = 'prom/blackbox-exporter:latest',
  String[1]                      $node_exporter_image       = 'quay.io/prometheus/node-exporter:latest',
  String[1]                      $wg_portal_image           = 'wgportal/wg-portal:v2',

  # SSO images
  String[1]                      $authelia_image            = 'authelia/authelia:4.38',
  String[1]                      $nginx_image               = 'nginx:1.25-alpine',
  String[1]                      $redis_image               = 'redis:7-alpine',

  # SSO configuration
  Optional[String[1]]            $domain_name               = undef,
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
) {
  if $manage_monitoring {
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
    if $enable_prometheus {
      file { "${monitoring_dir}/prometheus.yaml":
        ensure  => file,
        content => template('profile/monitoring/prometheus.yaml.erb'),
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

    # Create secrets directory if any secrets are defined
    if $grafana_admin_password or $pihole_password or $pihole_api_token {
      file { "${monitoring_dir}/secrets":
        ensure => directory,
        group  => $monitoring_dir_group,
        mode   => '0700',
        owner  => $monitoring_dir_owner,
      }

      if $grafana_admin_password {
        file { "${monitoring_dir}/secrets/grafana_admin_password":
          ensure  => file,
          content => $grafana_admin_password,
          group   => $monitoring_dir_group,
          mode    => '0600',
          owner   => $monitoring_dir_owner,
          require => File["${monitoring_dir}/secrets"],
        }
      }

      if $pihole_password {
        file { "${monitoring_dir}/secrets/pihole_password":
          ensure  => file,
          content => $pihole_password,
          group   => $monitoring_dir_group,
          mode    => '0600',
          owner   => $monitoring_dir_owner,
          require => File["${monitoring_dir}/secrets"],
        }
      }

      if $pihole_api_token {
        file { "${monitoring_dir}/secrets/pihole_api_token":
          ensure  => file,
          content => $pihole_api_token,
          group   => $monitoring_dir_group,
          mode    => '0600',
          owner   => $monitoring_dir_owner,
          require => File["${monitoring_dir}/secrets"],
        }
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
    }
  }
}
