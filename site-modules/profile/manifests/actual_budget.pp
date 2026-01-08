class profile::actual_budget (
  String $dir = '/opt/actual_budget/actual-data',
  String $port = '5006',
  String $image_tag = 'latest',
  String $image_name = 'actual_server',
) {
  file { $dir:
    ensure => directory,
    owner  => 'root',
    group  => 'root',
    mode   => '0755',
  }

  file { "${dir}/docker-compose.yaml":
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => template('profile/actual_budget/docker-compose.yaml.erb'),
    require => File[$dir],
  }

  exec { 'start-actual-budget':
    command     => '/usr/bin/docker-compose up -d',
    cwd         => $dir,
    refreshonly => true,
    subscribe   => File["${dir}/docker-compose.yaml"],
    require     => File["${dir}/docker-compose.yaml"],
  }
}
