#!/usr/bin/env ruby
# frozen_string_literal: true

# Check that all Puppet manifests have corresponding spec tests

require 'pathname'

EXIT_SUCCESS = 0
EXIT_FAILURE = 1

def find_manifests(base_dir)
  Dir.glob("#{base_dir}/**/manifests/**/*.pp").map { |f| Pathname.new(f) }
end

def expected_spec_path(manifest_path)
  # Convert: site-modules/profile/manifests/foo.pp
  #       -> site-modules/profile/spec/classes/foo_spec.rb
  # Convert: site-modules/profile/manifests/foo/bar.pp
  #       -> site-modules/profile/spec/classes/foo/bar_spec.rb

  path_str = manifest_path.to_s

  # Extract the module name and relative path
  return unless path_str =~ %r{site-modules/([^/]+)/manifests/(.+)\.pp$}

  module_name = Regexp.last_match(1)
  relative_path = Regexp.last_match(2)

  "site-modules/#{module_name}/spec/classes/#{relative_path}_spec.rb"
end

# rubocop:disable Metrics/MethodLength
def check_coverage
  missing_tests = []

  # Only check profile module (roles eliminated in Foreman ENC-first architecture)
  %w[profile].each do |module_name|
    base_dir = "site-modules/#{module_name}"
    next unless Dir.exist?(base_dir)

    manifests = find_manifests(base_dir)

    manifests.each do |manifest|
      # Skip init.pp files (they're typically just placeholders)
      next if manifest.basename.to_s == 'init.pp'

      spec_path = expected_spec_path(manifest)

      next if File.exist?(spec_path)

      missing_tests << {
        manifest: manifest.to_s,
        expected_spec: spec_path
      }
    end
  end

  missing_tests
end
# rubocop:enable Metrics/MethodLength

# Main execution
puts 'Checking test coverage for Puppet manifests...'
puts

missing_tests = check_coverage

if missing_tests.empty?
  puts '✓ All manifests have corresponding spec tests'
  exit EXIT_SUCCESS
else
  puts "✗ Found #{missing_tests.length} manifest(s) without spec tests:"
  puts

  missing_tests.each do |item|
    puts "  Manifest: #{item[:manifest]}"
    puts "  Expected: #{item[:expected_spec]}"
    puts
  end

  puts 'Please add spec tests for all manifests before pushing.'
  exit EXIT_FAILURE
end
