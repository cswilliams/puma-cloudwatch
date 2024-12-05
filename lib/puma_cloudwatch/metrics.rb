# frozen_string_literal: true

require 'puma_cloudwatch/metrics/fetcher'
require 'puma_cloudwatch/metrics/looper'
require 'puma_cloudwatch/metrics/parser'
require 'puma_cloudwatch/metrics/sender'
require 'puma_cloudwatch/metrics/storage'

module PumaCloudwatch
  # Metrics module
  class Metrics
    def self.start_sending(launcher)
      @looper = Looper.new(launcher.options)
      @looper.run
    end

    def self.stop_sending
      @looper.stop
    end
  end
end
