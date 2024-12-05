# frozen_string_literal: true

RSpec.describe PumaCloudwatch::Metrics::Parser do
  describe '#call' do
    subject(:parse) { parser.call }

    let(:fetcher) { instance_double(PumaCloudwatch::Metrics::Fetcher) }
    let(:parser) { described_class.new(fetcher) }

    before do
      allow(fetcher).to receive(:call).and_return(data)
    end

    context 'when stats are nil' do
      let(:data) { nil }

      it 'raises an InvalidStatsError' do
        expect { parse }.to raise_error(described_class::InvalidStatsError, 'Stats cannot be nil')
      end
    end

    context 'when in single mode' do
      let(:data) do
        {
          'started_at' => '2019-09-16T19:20:12Z',
          'backlog' => 0,
          'running' => 16,
          'pool_capacity' => 8,
          'requests_count' => 5
        }
      end

      it 'returns an array with one metrics hash' do
        expect(parse).to eq({
                              backlog: [data['backlog']],
                              pool_capacity: [data['pool_capacity']],
                              requests_count: [data['requests_count']]
                            })
      end
    end

    context 'when in cluster mode' do
      let(:worker_metrics) do
        data['worker_status'].map { |worker| worker['last_status'] }
      end

      let(:base_cluster_data) do
        {
          'started_at' => '2019-09-16T16:12:11Z',
          'workers' => 2,
          'phase' => 0,
          'booted_workers' => 2,
          'old_workers' => 0,
          'worker_status' => [
            {
              'started_at' => '2019-09-16T16:12:11Z',
              'pid' => 19_832,
              'index' => 0,
              'phase' => 0,
              'booted' => true,
              'last_checkin' => '2019-09-16T16:12:41Z',
              'last_status' => {
                'backlog' => 0,
                'running' => 1,
                'pool_capacity' => 16,
                'requests_count' => 5
              }
            },
            {
              'started_at' => '2019-09-16T16:12:11Z',
              'pid' => 19_836,
              'index' => 1,
              'phase' => 0,
              'booted' => true,
              'last_checkin' => '2019-09-16T16:12:41Z',
              'last_status' => {
                'backlog' => 0,
                'running' => 16,
                'pool_capacity' => 8,
                'requests_count' => 6
              }
            }
          ]
        }
      end

      context 'when last_status is empty' do
        let(:data) do
          base_cluster_data.tap do |d|
            d['worker_status'].each { |w| w['last_status'] = {} }
          end
        end

        it 'returns empty arrays for all metrics' do
          expect(parse).to eq({
                                backlog: [],
                                pool_capacity: [],
                                requests_count: []
                              })
        end
      end

      context 'when last_status contains metrics' do
        let(:data) { base_cluster_data }

        it 'returns an array with metrics for each worker' do
          expect(parse).to eq({
                                backlog: worker_metrics.map { |metrics| metrics['backlog'] },
                                pool_capacity: worker_metrics.map { |metrics| metrics['pool_capacity'] },
                                requests_count: worker_metrics.map { |metrics| metrics['requests_count'] }
                              })
        end
      end

      context 'when some workers have missing metrics' do
        let(:data) do
          base_cluster_data.tap do |d|
            first_worker = d['worker_status'][0]['last_status']
            first_worker.delete('pool_capacity')
            first_worker.delete('requests_count')
          end
        end

        it 'only includes available metrics in the result' do
          expect(parse).to eq({
                                backlog: worker_metrics.map { |metrics| metrics['backlog'] },
                                pool_capacity: worker_metrics.map { |metrics| metrics['pool_capacity'] }.compact,
                                requests_count: worker_metrics.map { |metrics| metrics['requests_count'] }.compact
                              })
        end
      end
    end
  end
end
