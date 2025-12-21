# @summary Manages OpenTelemetry Collector for Claude Code monitoring
#
# This profile sets up an OpenTelemetry Collector to receive metrics from Claude Code
# and forwards them to Prometheus for monitoring and alerting. Includes Grafana
# dashboards for visualization of cost, token usage, and performance metrics.
#
# @param manage_otel_collector
#   Whether to manage the OTEL collector
# @param otel_dir
#   Directory for OTEL collector configuration and data
# @param otel_grpc_port
#   gRPC port for receiving OTEL metrics
# @param otel_http_port
#   HTTP port for receiving OTEL metrics
# @param otel_health_port
#   Health check port for OTEL collector
# @param otel_pprof_port
#   pprof profiling port for OTEL collector
# @param otel_prometheus_port
#   Port for Prometheus metrics export
# @param prometheus_scrape_interval
#   How often Prometheus scrapes metrics
# @param otel_collector_image
#   Docker image for OTEL collector
# @param enable_grafana_dashboards
#   Whether to create Grafana dashboards
# @param grafana_datasource_name
#   Name of the Prometheus datasource in Grafana
#
# @example Basic usage
#   include profile::otel_collector
#
# @example Custom configuration via Hiera
#   profile::otel_collector::otel_grpc_port: 4317
#   profile::otel_collector::enable_grafana_dashboards: true
#
class profile::otel_collector (
  Boolean              $manage_otel_collector     = true,
  Stdlib::Absolutepath $otel_dir                  = '/opt/otel',
  Integer[1,65535]     $otel_grpc_port            = 4317,
  Integer[1,65535]     $otel_http_port            = 4318,
  Integer[1,65535]     $otel_health_port          = 13133,
  Integer[1,65535]     $otel_pprof_port           = 1777,
  Integer[1,65535]     $otel_prometheus_port      = 8889,
  String[1]            $prometheus_scrape_interval = '15s',
  String[1]            $otel_collector_image      = 'otel/opentelemetry-collector-contrib:latest',
  Boolean              $enable_grafana_dashboards = true,
  String[1]            $grafana_datasource_name   = 'Prometheus',
) {
  if $manage_otel_collector {
    # Create OTEL directory structure
    file { [$otel_dir, "${otel_dir}/config", "${otel_dir}/dashboards"]:
      ensure => directory,
      mode   => '0755',
      owner  => 'root',
      group  => 'root',
    }

    # OTEL Collector configuration
    file { "${otel_dir}/config/otel-collector-config.yaml":
      ensure  => file,
      mode    => '0644',
      owner   => 'root',
      group   => 'root',
      content => epp('profile/otel/otel-collector-config.yaml.epp', {
        grpc_port       => $otel_grpc_port,
        http_port       => $otel_http_port,
        health_port     => $otel_health_port,
        pprof_port      => $otel_pprof_port,
        prometheus_port => $otel_prometheus_port,
      }),
      require => File["${otel_dir}/config"],
    }

    # Docker Compose for OTEL Collector
    file { "${otel_dir}/docker-compose.yaml":
      ensure  => file,
      mode    => '0644',
      owner   => 'root',
      group   => 'root',
      content => epp('profile/otel/docker-compose.yaml.epp', {
        otel_dir             => $otel_dir,
        otel_collector_image => $otel_collector_image,
        grpc_port            => $otel_grpc_port,
        http_port            => $otel_http_port,
        health_port          => $otel_health_port,
        pprof_port           => $otel_pprof_port,
        prometheus_port      => $otel_prometheus_port,
      }),
      require => File[$otel_dir],
    }

    # Grafana dashboards for Claude Code monitoring
    if $enable_grafana_dashboards {
      file { "${otel_dir}/dashboards/claude-code-overview.json":
        ensure  => file,
        mode    => '0644',
        owner   => 'root',
        group   => 'root',
        content => epp('profile/otel/claude-code-overview.json.epp', {
          datasource_name => $grafana_datasource_name,
        }),
        require => File["${otel_dir}/dashboards"],
      }

      file { "${otel_dir}/dashboards/claude-code-costs.json":
        ensure  => file,
        mode    => '0644',
        owner   => 'root',
        group   => 'root',
        content => epp('profile/otel/claude-code-costs.json.epp', {
          datasource_name => $grafana_datasource_name,
        }),
        require => File["${otel_dir}/dashboards"],
      }
    }

    # Environment file for Docker Compose
    file { "${otel_dir}/.env":
      ensure  => file,
      mode    => '0644',
      owner   => 'root',
      group   => 'root',
      content => epp('profile/otel/.env.epp', {
        grpc_port       => $otel_grpc_port,
        http_port       => $otel_http_port,
        health_port     => $otel_health_port,
        pprof_port      => $otel_pprof_port,
        prometheus_port => $otel_prometheus_port,
      }),
      require => File[$otel_dir],
    }

    # Systemd service for OTEL Collector
    file { '/etc/systemd/system/otel-collector.service':
      ensure  => file,
      mode    => '0644',
      owner   => 'root',
      group   => 'root',
      content => epp('profile/otel/otel-collector.service.epp', {
        otel_dir => $otel_dir,
      }),
    }

    # Enable and start OTEL Collector service
    service { 'otel-collector':
      ensure    => running,
      enable    => true,
      subscribe => [
        File["${otel_dir}/docker-compose.yaml"],
        File["${otel_dir}/config/otel-collector-config.yaml"],
        File["${otel_dir}/.env"],
        File['/etc/systemd/system/otel-collector.service'],
      ],
      require   => [
        File['/etc/systemd/system/otel-collector.service'],
        Exec['systemctl-daemon-reload-otel'],
      ],
    }

    # Reload systemd after creating service file
    exec { 'systemctl-daemon-reload-otel':
      command     => '/bin/systemctl daemon-reload',
      refreshonly => true,
      subscribe   => File['/etc/systemd/system/otel-collector.service'],
    }
  }
}
