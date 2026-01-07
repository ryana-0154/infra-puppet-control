# @summary Standalone Grafana Alloy agent for shipping logs and metrics to Grafana Cloud
#
# This profile sets up Grafana Alloy as a standalone agent that can be assigned
# to any node to collect and forward metrics and logs to Grafana Cloud.
#
# @note Requirements
#   - Docker must be installed and running
#
# @param manage_alloy
#   Whether to manage Alloy configuration
# @param alloy_dir
#   Directory for Alloy configuration and data
# @param alloy_image
#   Docker image for Grafana Alloy
# @param alloy_http_port
#   HTTP port for Alloy UI and API
# @param bind_address
#   IP address to bind Alloy services to (default: 0.0.0.0)
#
# @param enable_metrics
#   Whether to collect and forward metrics
# @param enable_logs
#   Whether to collect and forward logs
# @param enable_node_exporter
#   Whether to run embedded node_exporter for system metrics
#
# @param grafana_cloud_metrics_url
#   Prometheus remote write URL for Grafana Cloud
# @param grafana_cloud_metrics_username
#   Username (instance ID) for Grafana Cloud metrics
# @param grafana_cloud_metrics_api_key
#   API key for Grafana Cloud metrics (should be encrypted with eyaml)
# @param grafana_cloud_logs_url
#   Loki push URL for Grafana Cloud
# @param grafana_cloud_logs_username
#   Username (instance ID) for Grafana Cloud logs
# @param grafana_cloud_logs_api_key
#   API key for Grafana Cloud logs (should be encrypted with eyaml)
#
# @param scrape_interval
#   How often to scrape metrics
# @param additional_scrape_targets
#   Additional Prometheus scrape targets as array of hashes
#   Each hash should have: name, address, and optionally metrics_path
#
# @example Basic usage with Grafana Cloud
#   class { 'profile::alloy':
#     grafana_cloud_metrics_url      => 'https://prometheus-prod-01-eu-west-0.grafana.net/api/prom/push',
#     grafana_cloud_metrics_username => '123456',
#     grafana_cloud_metrics_api_key  => Sensitive('glc_xxx'),
#     grafana_cloud_logs_url         => 'https://logs-prod-eu-west-0.grafana.net/loki/api/v1/push',
#     grafana_cloud_logs_username    => '654321',
#     grafana_cloud_logs_api_key     => Sensitive('glc_xxx'),
#   }
#
# @example With additional scrape targets
#   class { 'profile::alloy':
#     grafana_cloud_metrics_url      => 'https://...',
#     # ... other required params ...
#     additional_scrape_targets      => [
#       { 'name' => 'my_app', 'address' => 'localhost:8080', 'metrics_path' => '/metrics' },
#       { 'name' => 'redis', 'address' => 'localhost:9121' },
#     ],
#   }
#
class profile::alloy (
  Boolean                        $manage_alloy                    = true,
  Stdlib::Absolutepath           $alloy_dir                       = '/opt/alloy',
  String[1]                      $alloy_image                     = 'grafana/alloy:latest',
  Integer[1,65535]               $alloy_http_port                 = 12345,
  String[1]                      $bind_address                    = '0.0.0.0',

  # Feature flags (disabled by default - enable via Hiera with credentials)
  Boolean                        $enable_metrics                  = false,
  Boolean                        $enable_logs                     = false,
  Boolean                        $enable_node_exporter            = true,

  # Grafana Cloud configuration
  Optional[String[1]]            $grafana_cloud_metrics_url       = undef,
  Optional[String[1]]            $grafana_cloud_metrics_username  = undef,
  Optional[Variant[String[1], Sensitive[String[1]]]] $grafana_cloud_metrics_api_key = undef,
  Optional[String[1]]            $grafana_cloud_logs_url          = undef,
  Optional[String[1]]            $grafana_cloud_logs_username     = undef,
  Optional[Variant[String[1], Sensitive[String[1]]]] $grafana_cloud_logs_api_key = undef,

  # Scrape configuration
  String[1]                      $scrape_interval                 = '60s',
  Array[Hash]                    $additional_scrape_targets       = [],
) {
  # Multi-source parameter resolution (Foreman ENC -> Hiera -> Defaults)
  $_grafana_cloud_metrics_url_enc = getvar('alloy_grafana_cloud_metrics_url')
  $_grafana_cloud_metrics_url_hiera = lookup('profile::alloy::grafana_cloud_metrics_url', Optional[String], 'first', undef)
  $_grafana_cloud_metrics_url = $_grafana_cloud_metrics_url_enc ? {
    undef   => $_grafana_cloud_metrics_url_hiera ? {
      undef   => $grafana_cloud_metrics_url,
      default => $_grafana_cloud_metrics_url_hiera,
    },
    default => $_grafana_cloud_metrics_url_enc,
  }

  $_grafana_cloud_metrics_username_enc = getvar('alloy_grafana_cloud_metrics_username')
  $_grafana_cloud_metrics_username_hiera = lookup('profile::alloy::grafana_cloud_metrics_username', Optional[String], 'first', undef)
  $_grafana_cloud_metrics_username = $_grafana_cloud_metrics_username_enc ? {
    undef   => $_grafana_cloud_metrics_username_hiera ? {
      undef   => $grafana_cloud_metrics_username,
      default => $_grafana_cloud_metrics_username_hiera,
    },
    default => $_grafana_cloud_metrics_username_enc,
  }

  $_grafana_cloud_logs_url_enc = getvar('alloy_grafana_cloud_logs_url')
  $_grafana_cloud_logs_url_hiera = lookup('profile::alloy::grafana_cloud_logs_url', Optional[String], 'first', undef)
  $_grafana_cloud_logs_url = $_grafana_cloud_logs_url_enc ? {
    undef   => $_grafana_cloud_logs_url_hiera ? {
      undef   => $grafana_cloud_logs_url,
      default => $_grafana_cloud_logs_url_hiera,
    },
    default => $_grafana_cloud_logs_url_enc,
  }

  $_grafana_cloud_logs_username_enc = getvar('alloy_grafana_cloud_logs_username')
  $_grafana_cloud_logs_username_hiera = lookup('profile::alloy::grafana_cloud_logs_username', Optional[String], 'first', undef)
  $_grafana_cloud_logs_username = $_grafana_cloud_logs_username_enc ? {
    undef   => $_grafana_cloud_logs_username_hiera ? {
      undef   => $grafana_cloud_logs_username,
      default => $_grafana_cloud_logs_username_hiera,
    },
    default => $_grafana_cloud_logs_username_enc,
  }

  # Handle sensitive API keys
  $_grafana_cloud_metrics_api_key_raw = getvar('alloy_grafana_cloud_metrics_api_key')
  $_grafana_cloud_metrics_api_key_hiera = lookup('profile::alloy::grafana_cloud_metrics_api_key', Optional[Variant[String, Sensitive[String]]], 'first', undef)
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

  $_grafana_cloud_logs_api_key_raw = getvar('alloy_grafana_cloud_logs_api_key')
  $_grafana_cloud_logs_api_key_hiera = lookup('profile::alloy::grafana_cloud_logs_api_key', Optional[Variant[String, Sensitive[String]]], 'first', undef)
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

  # Multi-source parameter resolution for feature flags (Foreman ENC -> Hiera -> Defaults)
  $_enable_metrics_enc = getvar('alloy_enable_metrics')
  $_enable_metrics = $_enable_metrics_enc ? {
    undef   => $enable_metrics,
    default => $_enable_metrics_enc,
  }

  $_enable_logs_enc = getvar('alloy_enable_logs')
  $_enable_logs = $_enable_logs_enc ? {
    undef   => $enable_logs,
    default => $_enable_logs_enc,
  }

  $_enable_node_exporter_enc = getvar('alloy_enable_node_exporter')
  $_enable_node_exporter = $_enable_node_exporter_enc ? {
    undef   => $enable_node_exporter,
    default => $_enable_node_exporter_enc,
  }

  # Validate required parameters when metrics are enabled
  if $_enable_metrics {
    if !$_grafana_cloud_metrics_url or !$_grafana_cloud_metrics_username or !$_grafana_cloud_metrics_api_key {
      fail('profile::alloy: grafana_cloud_metrics_url, grafana_cloud_metrics_username, and grafana_cloud_metrics_api_key are required when enable_metrics is true')
    }
  }

  # Validate required parameters when logs are enabled
  if $_enable_logs {
    if !$_grafana_cloud_logs_url or !$_grafana_cloud_logs_username or !$_grafana_cloud_logs_api_key {
      fail('profile::alloy: grafana_cloud_logs_url, grafana_cloud_logs_username, and grafana_cloud_logs_api_key are required when enable_logs is true')
    }
  }

  if $manage_alloy {
    # Ensure Docker Compose v2 is installed
    ensure_packages(['docker-compose-plugin'])

    # Create Alloy directory structure
    file { $alloy_dir:
      ensure => directory,
      owner  => 'root',
      group  => 'root',
      mode   => '0755',
    }

    # Determine hostname for labels
    $hostname = $facts['networking']['fqdn'] ? {
      undef   => $facts['networking']['hostname'] ? {
        undef   => 'unknown',
        default => $facts['networking']['hostname'],
      },
      default => $facts['networking']['fqdn'],
    }

    # Alloy configuration file
    file { "${alloy_dir}/config.alloy":
      ensure  => file,
      owner   => 'root',
      group   => 'root',
      mode    => '0644',
      content => epp('profile/alloy/config.alloy.epp', {
        enable_metrics                 => $_enable_metrics,
        enable_logs                    => $_enable_logs,
        enable_node_exporter           => $_enable_node_exporter,
        bind_address                   => $bind_address,
        scrape_interval                => $scrape_interval,
        additional_scrape_targets      => $additional_scrape_targets,
        grafana_cloud_metrics_url      => $_grafana_cloud_metrics_url,
        grafana_cloud_metrics_username => $_grafana_cloud_metrics_username,
        grafana_cloud_metrics_api_key  => $_grafana_cloud_metrics_api_key,
        grafana_cloud_logs_url         => $_grafana_cloud_logs_url,
        grafana_cloud_logs_username    => $_grafana_cloud_logs_username,
        grafana_cloud_logs_api_key     => $_grafana_cloud_logs_api_key,
        hostname                       => $hostname,
      }),
      require => File[$alloy_dir],
    }

    # Docker Compose file
    file { "${alloy_dir}/docker-compose.yaml":
      ensure  => file,
      owner   => 'root',
      group   => 'root',
      mode    => '0644',
      content => epp('profile/alloy/docker-compose.yaml.epp', {
        alloy_image     => $alloy_image,
        alloy_dir       => $alloy_dir,
        bind_address    => $bind_address,
        alloy_http_port => $alloy_http_port,
      }),
      require => File[$alloy_dir],
    }

    # Ensure Alloy container is running
    exec { 'start-alloy':
      command => 'docker compose up -d',
      cwd     => $alloy_dir,
      path    => ['/usr/bin', '/usr/local/bin', '/usr/sbin', '/bin', '/sbin', '/snap/bin'],
      unless  => "docker ps --format '{{.Names}}' | grep -q '^alloy$'",
      require => [
        File["${alloy_dir}/docker-compose.yaml"],
        File["${alloy_dir}/config.alloy"],
      ],
    }

    # Restart container when configuration changes
    exec { 'restart-alloy':
      command     => 'docker compose up -d --force-recreate',
      cwd         => $alloy_dir,
      path        => ['/usr/bin', '/usr/local/bin', '/usr/sbin', '/bin', '/sbin', '/snap/bin'],
      refreshonly => true,
      subscribe   => [
        File["${alloy_dir}/docker-compose.yaml"],
        File["${alloy_dir}/config.alloy"],
      ],
    }
  }
}
