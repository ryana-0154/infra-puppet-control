#!/usr/bin/env ruby
# frozen_string_literal: true

# Validates that manifests don't use deprecated or removed Puppet functions
# These functions were removed in Puppet 6+ and will cause catalog compilation failures

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

# Functions removed in Puppet 6+ that will cause catalog compilation failures
# Note: Only includes functions that are actually removed, not just deprecated
REMOVED_FUNCTIONS = {
  'has_key' => "'key' in $hash",
  'validate_string' => 'Use Puppet 4+ data types (String)',
  'validate_array' => 'Use Puppet 4+ data types (Array)',
  'validate_hash' => 'Use Puppet 4+ data types (Hash)',
  'validate_bool' => 'Use Puppet 4+ data types (Boolean)',
  'validate_integer' => 'Use Puppet 4+ data types (Integer)',
  'validate_numeric' => 'Use Puppet 4+ data types (Numeric)',
  'validate_re' => 'Use Puppet 4+ data types with Pattern',
  'validate_absolute_path' => 'Use Puppet 4+ data types (Stdlib::Absolutepath)',
  'is_string' => 'Use $var =~ String',
  'is_array' => 'Use $var =~ Array',
  'is_hash' => 'Use $var =~ Hash',
  'is_bool' => 'Use $var =~ Boolean',
  'is_integer' => 'Use $var =~ Integer',
  'is_numeric' => 'Use $var =~ Numeric',
  'type3x' => 'Removed in Puppet 6, use modern data types'
  # NOTE: getvar() is NOT removed - it's a valid stdlib function for accessing
  # top-scope variables from Foreman ENC parameters
}.freeze

# Functions that are deprecated but still work (warnings only)
DEPRECATED_FUNCTIONS = {
  'hiera' => 'Use lookup() function',
  'hiera_array' => 'Use lookup() with merge behavior',
  'hiera_hash' => 'Use lookup() with merge behavior',
  'hiera_include' => 'Use lookup() with contain()',
  'create_resources' => 'Use iteration or defined types'
}.freeze

puts 'Validating for removed/deprecated Puppet functions...'.yellow
puts

removed_errors = []
deprecated_warnings = []
file_count = 0

# Check all Puppet manifests
# rubocop:disable Metrics/BlockLength
Dir.glob('site-modules/**/*.pp').each do |file|
  # Skip test files
  next if file.include?('/spec/')

  file_count += 1
  content = File.read(file)
  line_number = 0

  content.each_line do |line|
    line_number += 1

    # Skip comments
    next if line.strip.start_with?('#')
    next if line.strip.empty?

    # Check for removed functions (ERRORS)
    REMOVED_FUNCTIONS.each do |func, replacement|
      # Match function calls: func(...) or func (...)
      next unless line =~ /\b#{Regexp.escape(func)}\s*\(/

      removed_errors << {
        file: file,
        line: line_number,
        function: func,
        replacement: replacement,
        content: line.strip
      }
    end

    # Check for deprecated functions (WARNINGS)
    DEPRECATED_FUNCTIONS.each do |func, replacement|
      next unless line =~ /\b#{Regexp.escape(func)}\s*\(/

      deprecated_warnings << {
        file: file,
        line: line_number,
        function: func,
        replacement: replacement,
        content: line.strip
      }
    end
  end
end
# rubocop:enable Metrics/BlockLength

puts "Scanned #{file_count} manifest files"
puts

# Report deprecated functions as warnings
unless deprecated_warnings.empty?
  puts "WARNING: Found #{deprecated_warnings.size} uses of deprecated functions:".yellow
  puts '(These still work but should be updated)'.yellow
  puts

  deprecated_warnings.group_by { |e| e[:function] }.each do |func, occurrences|
    puts "  #{func.yellow} (use: #{DEPRECATED_FUNCTIONS[func]})"
    occurrences.each do |error|
      puts "    #{error[:file]}:#{error[:line]}"
    end
  end
  puts
end

# Report removed functions as errors
if removed_errors.empty?
  puts 'SUCCESS: No removed functions found!'.green
  exit 0
else
  puts "ERROR: Found #{removed_errors.size} uses of REMOVED functions:".red
  puts

  removed_errors.group_by { |e| e[:function] }.each do |func, occurrences|
    puts "  #{func.red} (use: #{REMOVED_FUNCTIONS[func]})"
    occurrences.each do |error|
      puts "    #{error[:file]}:#{error[:line]}"
      puts "      #{error[:content]}"
    end
    puts
  end

  puts 'These functions were REMOVED in Puppet 6+ and WILL cause catalog compilation failures.'.red
  puts 'Update your code immediately to use modern Puppet 4+ syntax.'.red
  puts

  exit 1
end
