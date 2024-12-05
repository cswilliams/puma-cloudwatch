# frozen_string_literal: true

require 'concurrent'

module PumaCloudwatch
  class Metrics
    # This class is responsible for running the metrics collection and sending
    # the aggregated metrics to CloudWatch
    class Looper
      DEFAULT_COLLECT_FREQUENCY = 5
      DEFAULT_SEND_FREQUENCY = 60

      attr_reader :control_url, :control_auth_token, :collect_frequency, :send_frequency, :storage,
                  :enabled, :parser, :sender

      class ControlAppError < StandardError; end

      def initialize(options)
        @control_url = options[:control_url]
        @control_auth_token = options[:control_auth_token]
        @collect_frequency = Integer(ENV['PUMA_CLOUDWATCH_COLLECT_FREQUENCY'] || DEFAULT_COLLECT_FREQUENCY)
        @send_frequency = Integer(ENV['PUMA_CLOUDWATCH_SEND_FREQUENCY'] || DEFAULT_SEND_FREQUENCY)
        @enabled = ENV['PUMA_CLOUDWATCH_ENABLED'] || false
        @storage = Storage.new(send_frequency)
        @parser = Parser.new(Fetcher.new(options))
        @sender = Sender.new(send_frequency)
      end

      def run
        return unless enabled?
        raise ControlAppError, 'Puma control app is not activated' if control_url.nil?

        @collect_thread = Thread.new { collect_metrics }
        @send_thread = Thread.new { send_metrics }
      end

      # Used for testing only
      def stop
        @collect_thread&.kill
        @send_thread&.kill
      end

      private

      def collect_metrics
        loop do
          sleep collect_frequency
          storage.aggregate(parser.call)
        rescue StandardError => e
          puts "PumaCloudwatch Error: #{e.message} (#{e.class})"
        end
      end

      def send_metrics
        loop do
          sleep send_frequency
          cutoff_time = Time.now.to_f - send_frequency
          metrics_to_send = storage.extract_metrics(cutoff_time)
          sender.call(metrics_to_send) unless metrics_to_send.empty?
        rescue StandardError => e
          puts "PumaCloudwatch Error: #{e.message} (#{e.class})"
        end
      end

      def enabled?
        !!enabled
      end
    end
  end
end
