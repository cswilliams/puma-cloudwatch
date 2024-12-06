# frozen_string_literal: true

require_relative 'lib/puma_cloudwatch/version'

Gem::Specification.new do |spec|
  spec.name          = 'puma-cloudwatch'
  spec.version       = PumaCloudwatch::VERSION
  spec.authors       = ['Tung Nguyen']
  spec.email         = ['tongueroo@gmail.com']

  spec.summary       = 'Puma plugin sends puma stats to CloudWatch'
  spec.homepage      = 'https://github.com/boltops-tools/puma-cloudwatch'
  spec.license       = 'MIT'

  spec.files         = Dir['lib/**/*']
  spec.require_paths = ['lib']

  spec.required_ruby_version = '>= 3.1.0'
  spec.add_dependency 'aws-sdk-cloudwatch', '~> 1'
  spec.add_dependency 'base64'
  spec.add_dependency 'concurrent-ruby', '~> 1'
  spec.add_dependency 'puma'
  spec.add_dependency 'rexml'
  spec.metadata['rubygems_mfa_required'] = 'true'
end
