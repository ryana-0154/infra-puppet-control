#!/usr/bin/env ruby
# frozen_string_literal: true

# Validates that all included/required classes actually exist
# This catches issues like including 'apt::unattended_upgrades' when it doesn't exist

require 'json'
require 'set'

# Colors for output
class String
  def red
    "\e[31m#{self}\e[0m"
  end

  def green
    "\e[32m#{self}\e[0m"
  end

  def yellow
    "\e[33m#{self}\e[0m"
  end
end

# Find all class definitions in manifests
# rubocop:disable Metrics/AbcSize, Metrics/MethodLength
def find_defined_classes(search_paths)
  defined_classes = Set.new

  search_paths.each do |path|
    next unless File.directory?(path)

    Dir.glob("#{path}/**/manifests/**/*.pp").each do |file|
      content = File.read(file)

      # Match class definitions: class foo::bar { ... }
      content.scan(/^\s*class\s+([a-z0-9_:]+)\s*[({]/) do |match|
        defined_classes.add(match[0])
      end

      # Also add implicit class from file path
      # modules/foo/manifests/bar/baz.pp defines foo::bar::baz
      next unless file =~ %r{([^/]+)/manifests/(.+)\.pp$}

      module_name = Regexp.last_match(1)
      subpath = Regexp.last_match(2)

      class_name = if subpath == 'init'
                     module_name
                   else
                     "#{module_name}::#{subpath.gsub('/', '::')}"
                   end

      defined_classes.add(class_name)
    end
  end

  defined_classes
end
# rubocop:enable Metrics/AbcSize, Metrics/MethodLength

# Find all class includes/requires in manifests
# rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength
# rubocop:disable Metrics/PerceivedComplexity, Metrics/BlockLength
def find_class_includes(search_paths)
  included_classes = {}

  search_paths.each do |path|
    next unless File.directory?(path)

    Dir.glob("#{path}/**/manifests/**/*.pp").each do |file|
      content = File.read(file)
      line_number = 0

      content.each_line do |line|
        line_number += 1

        # Skip comments and blank lines
        next if line.strip.start_with?('#')
        next if line.strip.empty?

        # Match include statements
        line.scan(/^\s*include\s+['"]?([a-z0-9_:]+)['"]?/) do |match|
          class_name = match[0]
          included_classes[class_name] ||= []
          included_classes[class_name] << { file: file, line: line_number, type: 'include' }
        end

        # Match require statements
        line.scan(/^\s*require\s+['"]?([a-z0-9_:]+)['"]?/) do |match|
          class_name = match[0]
          included_classes[class_name] ||= []
          included_classes[class_name] << { file: file, line: line_number, type: 'require' }
        end

        # Match contain statements
        line.scan(/^\s*contain\s+['"]?([a-z0-9_:]+)['"]?/) do |match|
          class_name = match[0]
          included_classes[class_name] ||= []
          included_classes[class_name] << { file: file, line: line_number, type: 'contain' }
        end

        # Match class { 'foo': } declarations
        line.scan(/^\s*class\s*\{\s*['"]([a-z0-9_:]+)['"]/) do |match|
          class_name = match[0]
          included_classes[class_name] ||= []
          included_classes[class_name] << { file: file, line: line_number, type: 'class {}' }
        end
      end
    end
  end

  included_classes
end
# rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength
# rubocop:enable Metrics/PerceivedComplexity, Metrics/BlockLength

puts 'Validating class includes...'.yellow
puts

# Define search paths
site_modules = ['site-modules/profile', 'site-modules/role']

# Look for modules in both spec/fixtures (testing) and modules/ (deployment)
# Prefer modules/ if it has content (deployed by r10k), otherwise use spec/fixtures
modules_dir = Dir.glob('modules/*').select { |f| File.directory?(f) }
spec_fixtures_dir = Dir.glob('spec/fixtures/modules/*').select { |f| File.directory?(f) }

external_modules = if modules_dir.any?
                     modules_dir
                   elsif spec_fixtures_dir.any?
                     spec_fixtures_dir
                   else
                     []
                   end

all_paths = site_modules + external_modules

puts "Searching for class definitions in #{all_paths.size} modules..."
defined_classes = find_defined_classes(all_paths)
puts "Found #{defined_classes.size} defined classes".green
puts

puts 'Searching for class includes/requires in site-modules...'
included_classes = find_class_includes(site_modules)
puts "Found #{included_classes.size} unique included classes".green
puts

# Validate
errors = []
included_classes.each do |class_name, locations|
  next if defined_classes.include?(class_name)

  errors << {
    class: class_name,
    locations: locations
  }
end

if errors.empty?
  puts 'SUCCESS: All included classes are defined!'.green
  exit 0
else
  puts "ERROR: Found #{errors.size} included classes that don't exist:".red
  puts

  errors.each do |error|
    puts "  #{error[:class].red}"
    error[:locations].each do |loc|
      puts "    #{loc[:type]} in #{loc[:file]}:#{loc[:line]}"
    end
    puts
  end

  puts 'Fix these issues by either:'.yellow
  puts '  1. Defining the missing classes'
  puts '  2. Adding the required module to Puppetfile'
  puts '  3. Removing the include/require statement'
  puts

  exit 1
end
