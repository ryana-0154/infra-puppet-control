# @summary Configures Puppet agent to connect to Puppet Server
#
# This profile manages Puppet agent configuration for nodes that need to
# connect to a Puppet Server. It configures the server hostname, CA server,
# and agent settings.
#
# @param manage_agent
#   Whether to manage Puppet agent configuration (default: true)
# @param server_hostname
#   Hostname of the Puppet Server to connect to (default: pi.ra-home.co.uk)
# @param ca_server
#   Hostname of the Certificate Authority server (default: pi.ra-home.co.uk)
# @param runinterval
#   How often the agent should run in seconds (default: 1800 = 30 minutes)
# @param environment
#   Puppet environment to use (default: production)
#
# @example Basic usage with Hiera
#   profile::puppet_agent::manage_agent: true
#   profile::puppet_agent::server_hostname: 'foreman01.ra-home.co.uk'
#   profile::puppet_agent::ca_server: 'pi.ra-home.co.uk'
#
class profile::puppet_agent (
  Boolean $manage_agent       = true,
  String[1] $server_hostname  = 'pi.ra-home.co.uk',
  String[1] $ca_server        = 'pi.ra-home.co.uk',
  Integer[60] $runinterval    = 1800,
  String[1] $environment      = 'production',
) {
  if $manage_agent {
    # Configure Puppet agent
    class { 'puppet':
      agent                 => true,
      agent_server_hostname => $server_hostname,
      ca_server             => $ca_server,
      runinterval           => $runinterval,
      environment           => $environment,
    }
  }
}
