# frozen_string_literal: true

require 'spec_helper'

describe 'profile::r10k' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      context 'with manage_r10k => false' do
        let(:params) do
          {
            manage_r10k: false
          }
        end

        it { is_expected.to compile.with_all_deps }
        it { is_expected.not_to contain_package('r10k') }
        it { is_expected.not_to contain_file('/etc/puppetlabs/r10k/r10k.yaml') }
      end

      context 'with manage_r10k => true' do
        let(:params) do
          {
            manage_r10k: true,
            git_remote: 'https://github.com/example/puppet-control.git'
          }
        end

        it { is_expected.to compile.with_all_deps }

        it {
          is_expected.to contain_package('r10k').with(
            ensure: 'installed',
            provider: 'puppet_gem'
          )
        }

        it {
          is_expected.to contain_file('/etc/puppetlabs/r10k').with(
            ensure: 'directory',
            owner: 'root',
            group: 'root',
            mode: '0755'
          )
        }

        it {
          is_expected.to contain_file('/etc/puppetlabs/r10k/r10k.yaml').with(
            ensure: 'file',
            owner: 'root',
            group: 'root',
            mode: '0644'
          )
        }

        it {
          is_expected.to contain_file('/etc/puppetlabs/r10k/r10k.yaml')
            .with_content(%r{cachedir: '/var/cache/r10k'})
        }

        it {
          is_expected.to contain_file('/etc/puppetlabs/r10k/r10k.yaml')
            .with_content(%r{remote: 'https://github\.com/example/puppet-control\.git'})
        }

        it {
          is_expected.to contain_file('/var/cache/r10k').with(
            ensure: 'directory',
            owner: 'root',
            group: 'root',
            mode: '0755'
          )
        }
      end

      context 'with auto_deploy => true' do
        let(:params) do
          {
            manage_r10k: true,
            auto_deploy: true
          }
        end

        it { is_expected.to compile.with_all_deps }

        it {
          is_expected.to contain_exec('r10k deploy environment').with(
            command: '/opt/puppetlabs/puppet/bin/r10k deploy environment -p',
            refreshonly: true,
            timeout: 600
          )
        }
      end

      context 'with manage_cron => true' do
        let(:params) do
          {
            manage_r10k: true,
            manage_cron: true,
            cron_minute: '*/30',
            cron_hour: '*'
          }
        end

        it { is_expected.to compile.with_all_deps }

        it {
          is_expected.to contain_cron('r10k-deploy').with(
            ensure: 'present',
            user: 'root',
            minute: '*/30',
            hour: '*'
          )
        }

        it {
          is_expected.to contain_file('/var/log/r10k-cron.log').with(
            ensure: 'file',
            owner: 'root',
            group: 'root',
            mode: '0644'
          )
        }
      end
    end
  end
end
