# Profile Module

This module contains Puppet profiles that compose technology stacks from Forge modules and site-specific resources.

## Foreman Integration

All profile classes support parameter configuration via **both**:
- **Hiera** (YAML data files in `data/` directory)
- **Foreman** (via Hiera override values in web UI)

### How Foreman Works with Hiera

Puppet uses automatic parameter lookup with Hiera as the data backend. When you configure override values in Foreman, you're actually populating Hiera data - Foreman can write these values to a YAML file that Hiera reads. This means you get UI-based configuration without manually editing YAML files.

### Configuring Parameters via Foreman

**Method 1: Smart Class Parameters (Recommended)**

1. Navigate to **Configure → Puppet Classes** in Foreman UI
2. Find your profile class (e.g., `profile::acme_server`)
3. Click **Smart Class Parameters** tab
4. For each parameter you want to set:
   - Check the **"Override"** checkbox
   - Set the **Default Value** or add host/hostgroup-specific matchers
   - Click **Submit**
5. Run `puppet agent -t` on the node

**Method 2: Hiera Override Values (via Foreman)**

1. Navigate to **Configure → Global Parameters** (or Host → Edit → Parameters)
2. Add parameters with full Hiera key names (e.g., `profile::acme_server::manage_acme`)
3. Foreman will make these available to Hiera lookups automatically
4. Run `puppet agent -t` on the node

**Method 3: Direct Hiera YAML Files**

Edit files in `data/` directory directly (e.g., `data/nodes/foreman01.ra-home.co.uk.yaml`):

```yaml
profile::acme_server::manage_acme: true
profile::acme_server::contact_email: 'admin@ra-home.co.uk'
profile::acme_server::profiles:
  cloudflare_dns01:
    challengetype: 'dns-01'
    options:
      env:
        CF_Token: 'your-token'
```

## Example: Configuring ACME Server

To enable Let's Encrypt certificate management on the Puppet Server:

1. **Via Foreman Smart Class Parameters**:
   - Navigate to `profile::acme_server` class in Foreman
   - Override `manage_acme` → `true`
   - Override `contact_email` → `admin@ra-home.co.uk`
   - Override `profiles` → `{ cloudflare_dns01: { challengetype: 'dns-01', ... } }`
   - Override `certificates` → `{ wildcard_ra_home: { domain: '*.ra-home.co.uk', use_profile: 'cloudflare_dns01' } }`

2. **Via Hiera YAML** (if not using Foreman):
   ```yaml
   profile::acme_server::manage_acme: true
   profile::acme_server::contact_email: 'admin@ra-home.co.uk'
   profile::acme_server::use_staging: false
   profile::acme_server::profiles:
     cloudflare_dns01:
       challengetype: 'dns-01'
       options:
         env:
           CF_Token: 'ENC[PKCS7,...]'  # encrypted with eyaml
   profile::acme_server::certificates:
     wildcard_ra_home:
       domain: '*.ra-home.co.uk ra-home.co.uk'  # space-separated for SANs
       use_profile: 'cloudflare_dns01'
   ```

## Profiles with Parameterized Classes

The following profiles use parameterized classes for configuration:
- `profile::acme_server` - Let's Encrypt certificate management
- `profile::puppetdb` - PuppetDB configuration for exported resources
- `profile::base` - Base system configuration
- `profile::monitoring` - Monitoring stack configuration

All parameters support automatic lookup from Hiera, which Foreman can populate via its override values feature.

## Why This Approach?

Puppet 6+ removed the `getvar()` function and other dynamic variable lookup functions. The modern, supported approach is to use automatic parameter lookup with Hiera as the backend. This works seamlessly with Foreman because Foreman can populate Hiera data via its override values system.

Benefits:
- **UI-based configuration** - Set parameters in Foreman web UI
- **No manual YAML editing** - Foreman manages Hiera data automatically
- **Type safety** - Parameters are strongly typed in the class definition
- **Standard pattern** - Uses Puppet's built-in automatic parameter lookup
- **No removed functions** - Works with modern Puppet 6+ without deprecated code

For more details, see: https://www.puppet.com/docs/puppet/latest/hiera_automatic.html
