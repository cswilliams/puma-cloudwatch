# frozen_string_literal: true

require 'concurrent'

module PumaCloudwatch
  class Metrics
    # Handles storage and aggregation of metrics
    class Storage
      attr_reader :metrics, :frequency

      def initialize(frequency)
        @metrics = Concurrent::Hash.new { |hash, key| hash[key] = Concurrent::Hash.new }
        @frequency = frequency
      end

      def aggregate(parsed_metrics)
        timestamp = calculate_timestamp

        parsed_metrics.each do |metric_name, values|
          stats = initialize_or_get_stats(timestamp, metric_name)
          update_stats(stats, values)
        end
      end

      def extract_metrics(cutoff_time)
        metrics_to_send = {}

        metrics.each_key do |timestamp|
          metrics_to_send[timestamp] = metrics.delete(timestamp) if timestamp <= cutoff_time
        end

        metrics_to_send
      end

      private

      def calculate_timestamp
        (Time.now.to_f / frequency).floor * frequency
      end

      def initialize_or_get_stats(timestamp, metric_name)
        metrics[timestamp][metric_name] ||= {
          min: Float::INFINITY,
          max: -Float::INFINITY,
          sum: 0.0,
          samples: 0
        }
      end

      def update_stats(stats, values)
        values.each do |value|
          stats[:min] = [stats[:min], value].min
          stats[:max] = [stats[:max], value].max
          stats[:sum] += value
          stats[:samples] += 1
        end
      end
    end
  end
end
