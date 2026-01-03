# Profile Module

This module contains Puppet profiles that compose technology stacks from Forge modules and site-specific resources.

## Foreman ENC Integration

All profile classes support parameter configuration via **both**:
- **Hiera** (YAML data files)
- **Foreman ENC** (Smart Class Parameters via web UI)

### How It Works

Puppet's `data_binding_terminus = hiera` means automatic parameter lookup only uses Hiera, not ENC top-scope variables. To support Foreman ENC, profiles use the `profile::param()` helper function which can find parameters from both sources.

### Using Foreman Smart Class Parameters

1. Navigate to **Configure → Puppet Classes** in Foreman UI
2. Find your profile class (e.g., `profile::acme_server`)
3. Click **Smart Class Parameters** tab
4. For each parameter you want to set:
   - Check the **"Override"** checkbox
   - Set the **Default Value** or add host/hostgroup-specific matchers
   - Click **Submit**
5. Run `puppet agent -t` on the node

### Converting a Profile to Support ENC

To add Foreman ENC support to a profile class, replace class parameters with `profile::param()` calls:

**Before (automatic parameter lookup - Hiera only):**
```puppet
class profile::example (
  Boolean $manage_service = false,
  String $config_file = '/etc/example/config.yaml',
  Hash $options = {},
) {
  # ... implementation ...
}
```

**After (explicit lookup - Hiera + ENC):**
```puppet
class profile::example {
  # Use profile::param() to support both Hiera and Foreman ENC
  $manage_service = profile::param('profile::example::manage_service', Boolean, false)
  $config_file = profile::param('profile::example::config_file', String, '/etc/example/config.yaml')
  $options = profile::param('profile::example::options', Hash, {})

  # ... implementation ...
}
```

### Profiles with ENC Support

The following profiles have been converted to support Foreman ENC:
- `profile::acme_server` - Let's Encrypt certificate management
- `profile::puppetdb` - PuppetDB configuration for exported resources

**To convert additional profiles**, follow the pattern shown in the "Converting a Profile" section above.

### Helper Function Reference

**`profile::param(key, type, default)`**

Performs parameter lookup from both Hiera and Foreman ENC Smart Class Parameters.

Parameters:
- `key` (String) - The parameter key (e.g., 'profile::example::manage_service')
- `type` (Type) - The expected data type (Boolean, String, Hash, etc.)
- `default` (Any) - Default value if parameter not found

Returns: The parameter value from Hiera, ENC, or the default

Example:
```puppet
$enabled = profile::param('profile::example::enabled', Boolean, false)
```

### Migration Strategy

Convert profiles to ENC support as needed:
1. Start with profiles you want to manage via Foreman UI
2. Use the pattern shown above
3. Keep the @param documentation for reference
4. Test with both Hiera and Foreman ENC to ensure compatibility

### Why Not Automatic?

You might wonder why we don't make this automatic for all profiles. The reason is:
- Puppet's automatic parameter lookup (with `data_binding_terminus = hiera`) explicitly only uses Hiera backends
- ENC parameters become top-scope variables but aren't part of the data binding system
- Explicit `lookup()` or `profile::param()` calls are needed to bridge this gap
- This is a well-known Puppet/Foreman integration pattern

For more details, see: https://www.puppet.com/docs/puppet/latest/hiera_automatic.html
