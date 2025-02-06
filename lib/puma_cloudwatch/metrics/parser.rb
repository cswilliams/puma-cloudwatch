# frozen_string_literal: true

module PumaCloudwatch
  class Metrics
    # Parses Puma stats into a format suitable for CloudWatch metrics
    #
    # @example Output format
    #   [{
    #     backlog: [0, 0],         # Number of connections in backlog per worker
    #     busy_threads: [16, 16], # running - threads waiting to receive work + requests waiting for a thread
    #     requests_count: [350, 475]    # Number of requests processed per worker
    #   }]
    #
    # All metrics are documented here: https://github.com/yob/puma-plugin-statsd/issues/27
    class Parser
      METRICS = %i[backlog busy_threads requests_count].freeze

      class InvalidStatsError < StandardError; end

      attr_reader :fetcher

      def initialize(fetcher)
        @fetcher = fetcher
      end

      def call
        stats = fetcher.call
        raise InvalidStatsError, 'Stats cannot be nil' if stats.nil?

        extract_metrics(stats)
      end

      private

      def extract_metrics(stats)
        metrics = initialize_metrics_hash

        if clustered_mode?(stats)
          parse_clustered_metrics(metrics, stats)
        else
          parse_single_mode_metrics(metrics, stats)
        end

        metrics.empty? ? nil : metrics
      end

      def initialize_metrics_hash
        METRICS.each_with_object({}) do |metric, hash|
          hash[metric] = []
        end
      end

      def clustered_mode?(stats)
        stats.key?('worker_status')
      end

      def parse_clustered_metrics(metrics, stats)
        worker_statuses(stats).each do |status|
          collect_metrics(metrics, status)
        end
      end

      def parse_single_mode_metrics(metrics, stats)
        collect_metrics(metrics, stats)
      end

      def worker_statuses(stats)
        stats['worker_status']
          .map { |status| status['last_status'] }
          .compact
      end

      def collect_metrics(metrics, status)
        METRICS.each do |metric|
          value = status[metric.to_s]
          metrics[metric] << value if value
        end
      end
    end
  end
end
