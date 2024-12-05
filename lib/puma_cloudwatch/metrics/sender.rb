# frozen_string_literal: true

require 'aws-sdk-cloudwatch'

module PumaCloudwatch
  class Metrics
    # This class is responsible for sending the aggregated metrics to CloudWatch
    class Sender
      attr_reader :frequency, :namespace, :cloudwatch

      DEFAULT_NAMESPACE = 'Puma'

      def initialize(frequency)
        @namespace = ENV['PUMA_CLOUDWATCH_NAMESPACE'] || DEFAULT_NAMESPACE
        @frequency = frequency
        @cloudwatch = Aws::CloudWatch::Client.new
      end

      def call(aggregated_metrics)
        cloudwatch.put_metric_data(namespace:, metric_data: metric_data(aggregated_metrics))
      end

      private

      def metric_data(aggregated_metrics)
        aggregated_metrics.flat_map do |timestamp, metrics|
          transform_metrics(metrics, timestamp)
        end
      end

      def transform_metrics(metrics, timestamp)
        metrics.map do |metric_name, stats|
          {
            metric_name: metric_name.to_s,
            storage_resolution: storage_resolution,
            statistic_values: build_statistics(stats),
            timestamp: Time.at(timestamp)
          }
        end
      end

      def storage_resolution
        frequency < 60 ? 1 : 60
      end

      def build_statistics(stats)
        {
          sample_count: stats[:samples],
          sum: stats[:sum],
          minimum: stats[:min],
          maximum: stats[:max]
        }
      end
    end
  end
end
