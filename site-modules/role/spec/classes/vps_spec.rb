# frozen_string_literal: true

require 'spec_helper'

describe 'role::vps' do
  let(:facts) do
    {
      os: {
        'family' => 'Debian',
        'name' => 'Ubuntu',
        'release' => {
          'major' => '22',
          'minor' => '04',
          'full' => '22.04'
        }
      },
      networking: {
        'fqdn' => 'vps.ra-home.co.uk',
        'hostname' => 'vps',
        'domain' => 'ra-home.co.uk'
      },
      kernel: 'Linux',
      kernelversion: '5.15.0',
      architecture: 'x86_64',
      operatingsystem: 'Ubuntu',
      operatingsystemrelease: '22.04',
      osfamily: 'Debian',
      lsbdistcodename: 'jammy',
      lsbdistid: 'Ubuntu'
    }
  end

  it { is_expected.to compile.with_all_deps }
  it { is_expected.to contain_class('profile::base') }
  it { is_expected.to contain_class('profile::unbound') }
  it { is_expected.to contain_class('profile::monitoring') }
  it { is_expected.to contain_file('/opt/monitoring') }
end
