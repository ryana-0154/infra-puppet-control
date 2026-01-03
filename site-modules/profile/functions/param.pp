# @summary Helper function to lookup parameters from both Hiera and Foreman ENC
#
# This function performs parameter lookup that works with both:
# - Hiera data (YAML files)
# - Foreman ENC Smart Class Parameters (top-scope variables)
#
# Puppet's automatic parameter lookup only uses Hiera when data_binding_terminus=hiera.
# ENC parameters become top-scope variables like $::profile::example::param
# This function checks both Hiera (via lookup) and top-scope (via getvar).
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
# @return The parameter value from Hiera, ENC top-scope, or the default
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
  # First, try to get the value from top-scope (where Foreman ENC parameters live)
  # ENC parameters are available as $::key
  $topscope_key = "::${key}"
  $topscope_value = getvar($topscope_key)

  # If found in top-scope and not undef, return it
  if $topscope_value =~ NotUndef {
    # Validate the type matches
    assert_type($type, $topscope_value)
    $topscope_value
  } else {
    # Fall back to Hiera lookup
    lookup($key, $type, 'first', $default)
  }
}
