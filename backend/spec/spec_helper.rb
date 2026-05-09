# frozen_string_literal: true

if ENV['COVERAGE']
  require 'simplecov'
  require 'simplecov-json'

  SimpleCov.formatters = [
    SimpleCov::Formatter::HTMLFormatter,
    SimpleCov::Formatter::JSONFormatter,
  ]
  SimpleCov.start 'rails' do
    add_filter '/spec/'
    add_filter '/vendor/'
    add_filter '/config/'
    add_filter '/db/'
    coverage_dir 'coverage'
    minimum_coverage 0
    add_group 'Commands', 'app/commands'
    add_group 'Interactors', 'app/interactors'
    add_group 'Services', 'app/services'
    add_group 'Channels', 'app/channels'
  end
end

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.filter_run_when_matching :focus
  config.example_status_persistence_file_path = 'spec/examples.txt'
  config.disable_monkey_patching!
  config.warnings = true

  config.order = :random
  Kernel.srand config.seed
end
