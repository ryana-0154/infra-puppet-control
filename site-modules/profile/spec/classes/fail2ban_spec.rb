# frozen_string_literal: true

require 'spec_helper'

describe 'profile::fail2ban' do
  on_supported_os.each do |os, os_facts|
    context "when running on #{os}" do
      let(:facts) { os_facts }

      context 'with default parameters' do
        it { is_expected.to compile.with_all_deps }

        it 'includes fail2ban class' do
          is_expected.to contain_class('fail2ban')
        end

        it 'configures fail2ban with default settings' do
          is_expected.to contain_class('fail2ban').with(
            package_ensure: 'present',
            service_ensure: 'running',
            service_enable: true,
            bantime: '1h',
            findtime: '10m',
            maxretry: 5
          )
        end

        it 'enables SSH jail by default with port 22' do
          is_expected.to contain_class('fail2ban').with_jails(
            hash_including(
              'sshd' => hash_including('enabled' => true, 'port' => 22)
            )
          )
        end

        it 'enables HTTP GET DoS jail by default' do
          is_expected.to contain_class('fail2ban').with_jails(
            hash_including(
              'http-get-dos' => hash_including('enabled' => true, 'maxretry' => 300)
            )
          )
        end

        it 'enables HTTP POST DoS jail by default' do
          is_expected.to contain_class('fail2ban').with_jails(
            hash_including(
              'http-post-dos' => hash_including('enabled' => true, 'maxretry' => 100)
            )
          )
        end
      end

      context 'when on Debian family' do
        let(:facts) { os_facts.merge({ os: { family: 'Debian' } }) }

        it 'uses Debian auth log path for SSH jail' do
          is_expected.to contain_class('fail2ban').with_jails(
            hash_including('sshd' => hash_including('logpath' => '/var/log/auth.log'))
          )
        end
      end

      context 'when on RedHat family' do
        let(:facts) { os_facts.merge({ os: { family: 'RedHat' } }) }

        it 'uses RedHat secure log path for SSH jail' do
          is_expected.to contain_class('fail2ban').with_jails(
            hash_including('sshd' => hash_including('logpath' => '/var/log/secure'))
          )
        end
      end

      context 'with custom SSH port' do
        let(:params) do
          {
            'ssh_port' => 2222
          }
        end

        it { is_expected.to compile.with_all_deps }

        it 'configures SSH jail with custom port' do
          is_expected.to contain_class('fail2ban').with_jails(
            hash_including(
              'sshd' => hash_including(
                'port' => 2222
              )
            )
          )
        end
      end

      context 'with SSH jail disabled' do
        let(:params) do
          {
            'enable_ssh_jail' => false
          }
        end

        it { is_expected.to compile.with_all_deps }

        it 'does not include sshd jail' do
          is_expected.to contain_class('fail2ban').with_jails(
            hash_not_including('sshd')
          )
        end

        it 'still includes HTTP jails' do
          is_expected.to contain_class('fail2ban').with_jails(
            hash_including('http-get-dos', 'http-post-dos')
          )
        end
      end

      context 'with HTTP jails disabled' do
        let(:params) do
          {
            'enable_http_jails' => false
          }
        end

        it { is_expected.to compile.with_all_deps }

        it 'does not include HTTP DoS jails' do
          is_expected.to contain_class('fail2ban').with_jails(
            hash_not_including('http-get-dos', 'http-post-dos')
          )
        end

        it 'still includes SSH jail' do
          is_expected.to contain_class('fail2ban').with_jails(
            hash_including('sshd')
          )
        end
      end

      context 'with all jails disabled' do
        let(:params) do
          {
            'enable_ssh_jail' => false,
            'enable_http_jails' => false
          }
        end

        it { is_expected.to compile.with_all_deps }

        it 'configures fail2ban with empty jails hash' do
          is_expected.to contain_class('fail2ban').with_jails({})
        end
      end

      context 'with custom bantime, findtime, and maxretry' do
        let(:params) do
          {
            'bantime' => '2h',
            'maxretry' => 3,
            'findtime' => '5m'
          }
        end

        it { is_expected.to compile.with_all_deps }

        it 'applies custom settings to fail2ban class' do
          is_expected.to contain_class('fail2ban').with(
            bantime: '2h',
            maxretry: 3,
            findtime: '5m'
          )
        end

        it 'applies custom settings to SSH jail' do
          is_expected.to contain_class('fail2ban').with_jails(
            hash_including(
              'sshd' => hash_including(
                'bantime' => '2h',
                'maxretry' => 3,
                'findtime' => '5m'
              )
            )
          )
        end
      end

      context 'with email notifications' do
        let(:params) do
          {
            'destemail' => 'admin@example.com',
            'sender' => 'fail2ban@example.com',
            'action' => 'action_mwl'
          }
        end

        it { is_expected.to compile.with_all_deps }

        it 'configures email settings' do
          is_expected.to contain_class('fail2ban').with(
            destemail: 'admin@example.com',
            sender: 'fail2ban@example.com',
            action: 'action_mwl'
          )
        end
      end

      context 'with custom jails' do
        let(:params) do
          {
            'custom_jails' => {
              'nginx-bad-request' => {
                'jail_name' => 'nginx-bad-request',
                'jail_content' => {
                  'nginx-bad-request' => {
                    'port' => 'http,https',
                    'logpath' => '/var/log/nginx/error.log',
                    'maxretry' => 2,
                    'bantime' => '1h'
                  }
                }
              }
            }
          }
        end

        it { is_expected.to compile.with_all_deps }

        it 'creates custom jail definition' do
          is_expected.to contain_fail2ban__jail('nginx-bad-request').with(
            jail_name: 'nginx-bad-request'
          )
        end
      end

      context 'with custom filters' do
        let(:params) do
          {
            'custom_filters' => {
              'custom-app' => {
                'filter_name' => 'custom-app',
                'filter_content' => {
                  'Definition' => {
                    'failregex' => '^.*Failed login.*<HOST>.*$'
                  }
                }
              }
            }
          }
        end

        it { is_expected.to compile.with_all_deps }

        it 'creates custom filter definition' do
          is_expected.to contain_fail2ban__filter('custom-app').with(
            filter_name: 'custom-app',
            filter_content: {
              'Definition' => {
                'failregex' => '^.*Failed login.*<HOST>.*$'
              }
            }
          )
        end
      end

      context 'with custom actions' do
        let(:params) do
          {
            'custom_actions' => {
              'slack-notify' => {
                'action_name' => 'slack',
                'action_content' => {
                  'Definition' => {
                    'actionban' => 'curl -X POST slack_webhook'
                  }
                }
              }
            }
          }
        end

        it { is_expected.to compile.with_all_deps }

        it 'creates custom action definition' do
          is_expected.to contain_fail2ban__action('slack-notify').with(
            action_name: 'slack',
            action_content: {
              'Definition' => {
                'actionban' => 'curl -X POST slack_webhook'
              }
            }
          )
        end
      end

      context 'with custom HTTP log paths' do
        let(:params) do
          {
            'http_logpath' => ['/var/log/custom/access.log']
          }
        end

        it { is_expected.to compile.with_all_deps }

        it 'uses custom log paths for HTTP jails' do
          is_expected.to contain_class('fail2ban').with_jails(
            hash_including(
              'http-get-dos' => hash_including(
                'logpath' => ['/var/log/custom/access.log']
              ),
              'http-post-dos' => hash_including(
                'logpath' => ['/var/log/custom/access.log']
              )
            )
          )
        end
      end

      context 'with fail2ban disabled' do
        let(:params) do
          {
            'manage_fail2ban' => false
          }
        end

        it { is_expected.to compile.with_all_deps }

        it 'does not include fail2ban class' do
          is_expected.not_to contain_class('fail2ban')
        end

        it 'does not create any custom jails' do
          is_expected.not_to contain_fail2ban__jail('nginx-bad-request')
        end
      end

      context 'with service stopped' do
        let(:params) do
          {
            'service_ensure' => 'stopped',
            'service_enable' => false
          }
        end

        it { is_expected.to compile.with_all_deps }

        it 'configures service as stopped and disabled' do
          is_expected.to contain_class('fail2ban').with(
            service_ensure: 'stopped',
            service_enable: false
          )
        end
      end
    end
  end
end
