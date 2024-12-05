# frozen_string_literal: true

RSpec.describe PumaCloudwatch::Metrics::Storage do
  subject(:storage) { described_class.new(send_frequency) }

  let(:send_frequency) { 60 } # 60 seconds
  let(:current_time) { Time.new(2023, 1, 1, 12, 0, 0) }

  before do
    allow(Time).to receive(:now).and_return(current_time)
  end

  describe '#initialize' do
    it 'creates an empty metrics hash' do
      expect(storage.metrics).to be_empty
    end

    it 'uses Concurrent::Hash for thread safety' do
      expect(storage.metrics).to be_a(Concurrent::Hash)
    end

    it 'sets the frequency' do
      expect(storage.frequency).to eq(send_frequency)
    end
  end

  describe '#aggregate' do
    let(:base_metrics) do
      {
        backlog: [0, 1],
        pool_capacity: [16, 32],
        requests_count: [7, 8]
      }
    end

    context 'when aggregating first metrics' do
      before do
        storage.aggregate(base_metrics)
      end

      let(:timestamp) { current_time.to_i - (current_time.to_i % send_frequency) }

      it 'stores metrics with correct timestamp' do
        expect(storage.metrics.keys).to contain_exactly(timestamp)
      end

      it 'calculates stats correctly' do
        aggregate_failures do
          base_metrics.each do |metric_name, values|
            stats = storage.metrics[timestamp][metric_name]
            expect(stats[:min]).to eq(values.min)
            expect(stats[:max]).to eq(values.max)
            expect(stats[:sum]).to eq(values.sum)
            expect(stats[:samples]).to eq(values.size)
          end
        end
      end
    end

    context 'when aggregating additional metrics in same time window' do
      let(:additional_metrics) do
        {
          backlog: [2],
          pool_capacity: [64],
          requests_count: [15]
        }
      end

      let(:timestamp) { current_time.to_i - (current_time.to_i % send_frequency) }

      before do
        storage.aggregate(base_metrics)
        storage.aggregate(additional_metrics)
      end

      it 'updates stats correctly' do
        aggregate_failures do
          base_metrics.each do |metric_name, values|
            additional_values = additional_metrics[metric_name]
            all_values = values + additional_values
            stats = storage.metrics[timestamp][metric_name]

            expect(stats[:min]).to eq(all_values.min)
            expect(stats[:max]).to eq(all_values.max)
            expect(stats[:sum]).to eq(all_values.sum)
            expect(stats[:samples]).to eq(all_values.size)
          end
        end
      end
    end
  end

  describe '#extract_metrics' do
    let(:old_timestamp) { current_time.to_i - 120 }
    let(:current_timestamp) { current_time.to_i - (current_time.to_i % send_frequency) }
    let(:old_metrics) { { backlog: [0], requests_count: [5] } }
    let(:current_metrics) { { backlog: [1], requests_count: [10] } }

    before do
      # Add metrics for old timestamp
      allow(Time).to receive(:now).and_return(Time.at(old_timestamp))
      storage.aggregate(old_metrics)

      # Add metrics for current timestamp
      allow(Time).to receive(:now).and_return(current_time)
      storage.aggregate(current_metrics)
    end

    context 'when extracting metrics before cutoff' do
      let(:cutoff_time) { current_time.to_i - 60 }
      let(:extracted) { storage.extract_metrics(cutoff_time) }

      it 'extracts timestamps' do
        expect(extracted.keys).to contain_exactly(old_timestamp)
      end

      it 'removes extracted metrics from storage' do
        extracted

        expect(storage.metrics.keys).to contain_exactly(current_timestamp)
      end
    end

    context 'when no metrics are before cutoff' do
      let(:cutoff_time) { current_time.to_i - 180 }
      let(:extracted) { storage.extract_metrics(cutoff_time) }

      it 'handles no metrics before cutoff correctly' do
        expect(extracted).to be_empty
      end

      it 'does not remove any metrics from storage' do
        extracted

        expect(storage.metrics.keys).to contain_exactly(old_timestamp, current_timestamp)
      end
    end
  end
end
