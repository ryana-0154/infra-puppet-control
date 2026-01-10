# site.pp - Foreman ENC-first architecture
#
# This control repository uses Foreman ENC for node classification.
# Profiles are assigned directly to hosts/hostgroups in Foreman,
# eliminating the need for role classes.
#
# Configuration flow:
# 1. Foreman ENC assigns profiles to nodes via hostgroups
# 2. Host/Hostgroup Parameters provide configuration values
# 3. Hiera provides fallback defaults only
#
# Only profile::base is applied by default as a safety net.
# All other profiles must be explicitly assigned in Foreman.
