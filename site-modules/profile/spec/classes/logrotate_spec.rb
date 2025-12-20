# frozen_string_literal: true

require 'spec_helper'

describe 'profile::logrotate' do
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
        'fqdn' => 'test.example.com',
        'hostname' => 'test',
        'domain' => 'example.com'
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

  context 'with default parameters' do
    it { is_expected.to compile.with_all_deps }
    it { is_expected.to contain_class('logrotate') }

    it do
      is_expected.to contain_class('logrotate').with(
        ensure: 'present',
        manage_wtmp: true,
        manage_btmp: true
      )
    end
  end

  context 'with manage_logrotate disabled' do
    let(:params) { { manage_logrotate: false } }

    it { is_expected.to compile.with_all_deps }
    it { is_expected.not_to contain_class('logrotate') }
  end

  context 'with custom rotation settings' do
    let(:params) do
      {
        rotate_period: 'daily',
        rotate_count: 7,
        compress: false
      }
    end

    it { is_expected.to compile.with_all_deps }
    it { is_expected.to contain_class('logrotate') }
  end

  context 'with custom logrotate rules' do
    let(:params) do
      {
        rules: {
          'apache2' => {
            'path' => '/var/log/apache2/*.log',
            'rotate' => 14,
            'compress' => true
          }
        }
      }
    end

    it { is_expected.to compile.with_all_deps }
    it { is_expected.to contain_logrotate__rule('apache2') }
  end
end
