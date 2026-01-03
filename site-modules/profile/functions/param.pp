# @summary Helper function to lookup parameters from both Hiera and Foreman ENC
#
# This function performs parameter lookup that works with both:
# - Hiera data (YAML files)
# - Foreman ENC Smart Class Parameters (top-scope variables)
#
# Puppet's automatic parameter lookup only uses Hiera when data_binding_terminus=hiera.
# This function uses lookup() which can find both Hiera data AND ENC top-scope variables.
#
# @param key
#   The parameter key to look up (e.g., 'profile::base::manage_firewall')
#
# @param type
#   The expected data type (e.g., Boolean, String, Hash, etc.)
#
# @param default
#   The default value if the parameter is not found
#
# @return The parameter value from Hiera, ENC, or the default
#
# @example Using in a profile class
#   class profile::example {
#     $manage_service = profile::param('profile::example::manage_service', Boolean, false)
#     $config_hash = profile::param('profile::example::config', Hash, {})
#   }
#
function profile::param(
  String $key,
  Type $type,
  Any $default,
) >> Any {
  # Use lookup() with 'first' merge strategy
  # This will check in order:
  # 1. Hiera data (if present)
  # 2. Environment/global scope (where Foreman ENC parameters live)
  # 3. Default value (if nothing found)
  lookup($key, $type, 'first', $default)
}
