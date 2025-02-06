# frozen_string_literal: true

RSpec.describe PumaCloudwatch::Metrics::Sender do
  subject(:sender) { described_class.new(frequency) }

  let(:custom_namespace) { 'CustomNamespace' }
  let(:frequency) { 60 }
  let(:timestamp) { Time.now.to_i }
  let(:aggregated_metrics) do
    {
      timestamp => {
        backlog: { min: 0, max: 0, sum: 0, samples: 12 },
        busy_threads: { min: 0, max: 3, sum: 18, samples: 12 },
        requests_count: { min: 3, max: 3, sum: 36, samples: 12 }
      }
    }
  end

  let(:cloudwatch_client) { instance_double(Aws::CloudWatch::Client) }

  before do
    allow(Aws::CloudWatch::Client).to receive(:new).and_return(cloudwatch_client)
    allow(sender).to receive(:puts)
    allow(cloudwatch_client).to receive(:put_metric_data)
  end

  describe '#initialize' do
    context 'with custom namespace' do
      let(:env) { { 'PUMA_CLOUDWATCH_NAMESPACE' => custom_namespace } }

      it 'sets the namespace from environment variable' do
        expect(sender.namespace).to eq(custom_namespace)
      end
    end

    context 'without custom namespace' do
      let(:env) { {} }

      it 'uses default namespace' do
        expect(sender.namespace).to eq(described_class::DEFAULT_NAMESPACE)
      end
    end

    it 'sets the frequency' do
      expect(sender.frequency).to eq(frequency)
    end

    it 'creates a new CloudWatch client' do
      expect(sender.cloudwatch).to eq(cloudwatch_client)
    end
  end

  describe '#call' do
    let(:env) { {} }
    let(:expected_params) do
      {
        namespace: described_class::DEFAULT_NAMESPACE,
        metric_data: aggregated_metrics.flat_map do |ts, metrics|
          metrics.map do |name, stats|
            {
              metric_name: name.to_s,
              storage_resolution: frequency,
              statistic_values: {
                sample_count: stats[:samples],
                sum: stats[:sum],
                minimum: stats[:min],
                maximum: stats[:max]
              },
              timestamp: Time.at(ts)
            }
          end
        end
      }
    end

    before do
      allow(sender).to receive(:puts)
    end

    it 'sends metrics to CloudWatch' do
      sender.call(aggregated_metrics)

      expect(cloudwatch_client).to have_received(:put_metric_data).with(expected_params)
    end

    context 'when the frequency is less than 60' do
      let(:frequency) { 30 }

      it 'sets the storage resolution to 1' do
        sender.call(aggregated_metrics)

        aggregate_failures do
          expect(cloudwatch_client).to have_received(:put_metric_data) do |params|
            params[:metric_data].each do |metric|
              expect(metric[:storage_resolution]).to eq(1)
            end
          end
        end
      end
    end
  end
end
