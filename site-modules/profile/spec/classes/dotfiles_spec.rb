# frozen_string_literal: true

require 'spec_helper'

describe 'profile::dotfiles' do
  on_supported_os.each do |os, os_facts|
    context "when running on #{os}" do
      let(:facts) { os_facts }

      context 'with default parameters' do
        it { is_expected.to compile.with_all_deps }

        it 'does not configure any users by default' do
          is_expected.not_to contain_vcsrepo(%r{.*/.dotfiles})
        end
      end

      context 'with manage_dotfiles disabled' do
        let(:params) { { manage_dotfiles: false } }

        it { is_expected.to compile.with_all_deps }
      end

      context 'with a single user' do
        let(:params) do
          {
            dotfiles_users: {
              'ryan' => {
                'home_dir' => '/home/ryan'
              }
            }
          }
        end

        it { is_expected.to compile.with_all_deps }

        it 'clones dotfiles repository' do
          is_expected.to contain_vcsrepo('/home/ryan/.dotfiles').with(
            ensure: 'present',
            provider: 'git',
            source: 'https://github.com/ryana-0154/dotfiles.git',
            revision: 'main',
            user: 'ryan'
          )
        end

        it 'ensures install script is executable' do
          is_expected.to contain_file('/home/ryan/.dotfiles/install').with(
            ensure: 'file',
            mode: '0755'
          )
        end

        it 'runs install script' do
          is_expected.to contain_exec('install-dotfiles-ryan').with(
            command: './install',
            cwd: '/home/ryan/.dotfiles',
            user: 'ryan',
            refreshonly: true
          )
        end
      end

      context 'with multiple users' do
        let(:params) do
          {
            dotfiles_users: {
              'ryan' => {
                'home_dir' => '/home/ryan'
              },
              'alice' => {
                'home_dir' => '/home/alice'
              }
            }
          }
        end

        it { is_expected.to compile.with_all_deps }

        it 'clones dotfiles for ryan' do
          is_expected.to contain_vcsrepo('/home/ryan/.dotfiles').with(
            user: 'ryan'
          )
        end

        it 'clones dotfiles for alice' do
          is_expected.to contain_vcsrepo('/home/alice/.dotfiles').with(
            user: 'alice'
          )
        end

        it 'runs install script for ryan' do
          is_expected.to contain_exec('install-dotfiles-ryan')
        end

        it 'runs install script for alice' do
          is_expected.to contain_exec('install-dotfiles-alice')
        end
      end

      context 'with auto_update enabled' do
        let(:params) do
          {
            auto_update: true,
            dotfiles_users: {
              'ryan' => {
                'home_dir' => '/home/ryan'
              }
            }
          }
        end

        it { is_expected.to compile.with_all_deps }

        it 'ensures repository is at latest' do
          is_expected.to contain_vcsrepo('/home/ryan/.dotfiles').with_ensure('latest')
        end
      end

      context 'with custom repository and revision' do
        let(:params) do
          {
            dotfiles_repo: 'https://github.com/custom/dotfiles.git',
            dotfiles_revision: 'develop',
            dotfiles_users: {
              'ryan' => {
                'home_dir' => '/home/ryan'
              }
            }
          }
        end

        it { is_expected.to compile.with_all_deps }

        it 'uses custom repository' do
          is_expected.to contain_vcsrepo('/home/ryan/.dotfiles').with(
            source: 'https://github.com/custom/dotfiles.git',
            revision: 'develop'
          )
        end
      end

      context 'with custom dotfiles directory name' do
        let(:params) do
          {
            dotfiles_dir_name: 'my-configs',
            dotfiles_users: {
              'ryan' => {
                'home_dir' => '/home/ryan'
              }
            }
          }
        end

        it { is_expected.to compile.with_all_deps }

        it 'uses custom directory name' do
          is_expected.to contain_vcsrepo('/home/ryan/my-configs')
        end
      end

      context 'with user ensure absent' do
        let(:params) do
          {
            dotfiles_users: {
              'ryan' => {
                'home_dir' => '/home/ryan',
                'ensure' => 'absent'
              }
            }
          }
        end

        it { is_expected.to compile.with_all_deps }

        it 'removes dotfiles directory' do
          is_expected.to contain_file('/home/ryan/.dotfiles').with(
            ensure: 'absent',
            force: true,
            recurse: true
          )
        end

        it 'does not clone repository' do
          is_expected.not_to contain_vcsrepo('/home/ryan/.dotfiles')
        end
      end

      context 'with install_git disabled' do
        let(:params) do
          {
            install_git: false,
            dotfiles_users: {
              'ryan' => {
                'home_dir' => '/home/ryan'
              }
            }
          }
        end

        it { is_expected.to compile.with_all_deps }

        it 'still clones repository' do
          is_expected.to contain_vcsrepo('/home/ryan/.dotfiles')
        end
      end

      context 'with user home_dir inferred' do
        let(:params) do
          {
            dotfiles_users: {
              'ryan' => {}
            }
          }
        end

        it { is_expected.to compile.with_all_deps }

        it 'infers home directory from username' do
          is_expected.to contain_vcsrepo('/home/ryan/.dotfiles')
        end
      end
    end
  end
end
