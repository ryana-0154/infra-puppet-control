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

desc 'Check test coverage for all manifests'
task :check_coverage do
  sh 'ruby scripts/check-test-coverage.rb'
end

desc 'Run all linting tasks'
task lint_all: %i[lint rubocop syntax]

desc 'Validate that all included classes exist'
task :validate_class_includes do
  sh 'ruby scripts/validate-class-includes.rb'
end

desc 'Validate no deprecated/removed Puppet functions are used'
task :validate_functions do
  sh 'ruby scripts/validate-deprecated-functions.rb'
end

desc 'Run catalog compilation acceptance tests'
task :acceptance do
  sh 'bundle exec rspec spec/acceptance'
end

desc 'Run all tests'
task test: %i[lint_all check_coverage spec validate_class_includes validate_functions]

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
