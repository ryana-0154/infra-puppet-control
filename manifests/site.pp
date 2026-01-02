# site.pp - Main manifest entry point
# This file is the main entry point for Puppet and should contain
# node definitions or include statements for classification

# VPS nodes
node 'vps.ra-home.co.uk' {
  include role::vps
}

node 'foreman01.ra-home.co.uk' {
  include role::foreman
}

# Default node - applies to all nodes not explicitly matched
node default {
  # Include the role class based on the node's role fact
  # or assign a default role
  include role::base
}

# Example: Define specific nodes
# node 'web01.example.com' {
#   include role::webserver
# }

# Example: Use regex for node matching
# node /^db\d+\.example\.com$/ {
#   include role::database
# }
