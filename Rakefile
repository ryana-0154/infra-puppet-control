# frozen_string_literal: true

require 'puppetlabs_spec_helper/rake_tasks'
require 'puppet-lint/tasks/puppet-lint'
require 'puppet-syntax/tasks/puppet-syntax'
require 'rubocop/rake_task'

# Exclude external modules from linting
PuppetLint.configuration.ignore_paths = [
  'modules/**/*',
  'vendor/**/*',
  'spec/fixtures/**/*'
]

PuppetSyntax.exclude_paths = [
  'modules/**/*',
  'vendor/**/*',
  'spec/fixtures/**/*',
  'data/examples/**/*'
]

# Puppet-lint configuration
PuppetLint.configuration.send('disable_80chars')
PuppetLint.configuration.send('disable_140chars')
PuppetLint.configuration.send('disable_class_inherits_from_params_class')
PuppetLint.configuration.send('disable_documentation')
PuppetLint.configuration.fail_on_warnings = true

RuboCop::RakeTask.new

desc 'Run all linting tasks'
task lint_all: %i[lint rubocop syntax]

desc 'Run all tests'
task test: %i[lint_all spec]

desc 'Validate manifests, templates, and ruby files'
task validate: %i[syntax validate_templates]

desc 'Validate ERB templates'
task :validate_templates do
  Dir['site-modules/*/templates/**/*.erb'].each do |template|
    sh "erb -P -x -T '-' #{template} | ruby -c" do |ok, _res|
      raise "Template validation failed for #{template}" unless ok
    end
  end
end

desc 'Run r10k puppetfile syntax check'
task :r10k_syntax do
  sh 'r10k puppetfile check'
end

desc 'Deploy modules with r10k'
task :r10k_deploy do
  sh 'r10k puppetfile install --verbose'
end

task default: :test
