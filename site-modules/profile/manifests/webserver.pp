# @summary Webserver profile
#
# Profile for configuring web servers. This is a template profile
# that should be customized for your specific web server needs.
#
# @param document_root
#   The document root for the web server
# @param server_name
#   The primary server name
#
# @example
#   include profile::webserver
#
class profile::webserver (
  Stdlib::Absolutepath $document_root = '/var/www/html',
  String               $server_name   = $facts['networking']['fqdn'],
) {
  # Add your web server configuration here
  # This is a placeholder for customization

  file { $document_root:
    ensure => directory,
    owner  => 'root',
    group  => 'root',
    mode   => '0755',
  }
}
