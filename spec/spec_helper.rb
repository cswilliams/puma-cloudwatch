# frozen_string_literal: true

require 'simplecov'
require 'simplecov-json'

SimpleCov.start do
  coverage_dir './coverage'
  add_filter '/spec/' # Excludes all files in the spec directory
end

SimpleCov.formatters = SimpleCov::Formatter::MultiFormatter.new(
  [SimpleCov::Formatter::HTMLFormatter, SimpleCov::Formatter::JSONFormatter]
)

require 'rspec'
require 'rspec/mocks'
require 'timecop'
require 'puma'
require 'puma/plugin'
require_relative '../lib/puma_cloudwatch'
require_relative '../lib/puma/plugin/cloudwatch'

RSpec.configure do |config|
  config.before do
    full_env = defined?(env) ? env : {}
    stub_const('ENV', full_env)
  end
end
