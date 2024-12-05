# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PumaCloudwatch::Metrics::Looper do
  subject(:looper) { described_class.new(options) }

  let(:control_url) { 'unix:///tmp/puma.sock' }
  let(:control_auth_token) { 'abc123' }
  let(:options) do
    {
      control_url: control_url,
      control_auth_token: control_auth_token
    }
  end
  let(:env) { {} }

  let(:sender) { instance_double(PumaCloudwatch::Metrics::Sender) }
  let(:fetcher) { instance_double(PumaCloudwatch::Metrics::Fetcher) }
  let(:parser) { instance_double(PumaCloudwatch::Metrics::Parser) }
  let(:storage) { instance_double(PumaCloudwatch::Metrics::Storage) }

  before do
    allow(PumaCloudwatch::Metrics::Sender).to receive(:new).and_return(sender)
    allow(PumaCloudwatch::Metrics::Fetcher).to receive(:new).and_return(fetcher)
    allow(PumaCloudwatch::Metrics::Parser).to receive(:new).and_return(parser)
    allow(PumaCloudwatch::Metrics::Storage).to receive(:new).and_return(storage)
  end

  describe '#initialize' do
    it 'sets control_url from options' do
      expect(looper.control_url).to eq(control_url)
    end

    it 'sets control_auth_token from options' do
      expect(looper.control_auth_token).to eq(control_auth_token)
    end

    it 'sets collect_frequency to default when environment variable is not set' do
      expect(looper.collect_frequency).to eq(described_class::DEFAULT_COLLECT_FREQUENCY)
    end

    context 'when PUMA_CLOUDWATCH_COLLECT_FREQUENCY is set' do
      let(:collect_frequency) { 10 }
      let(:env) { { 'PUMA_CLOUDWATCH_COLLECT_FREQUENCY' => collect_frequency.to_s } }

      it 'sets collect_frequency from environment variable' do
        expect(looper.collect_frequency).to eq(collect_frequency)
      end
    end

    it 'sets send_frequency to default when environment variable is not set' do
      expect(looper.send_frequency).to eq(described_class::DEFAULT_SEND_FREQUENCY)
    end

    context 'when PUMA_CLOUDWATCH_SEND_FREQUENCY is set' do
      let(:send_frequency) { 120 }
      let(:env) { { 'PUMA_CLOUDWATCH_SEND_FREQUENCY' => send_frequency.to_s } }

      it 'sets send_frequency from environment variable' do
        expect(looper.send_frequency).to eq(send_frequency)
      end
    end

    it 'sets enabled to false by default' do
      expect(looper.enabled).to be false
    end

    context 'when PUMA_CLOUDWATCH_ENABLED is set' do
      let(:enabled_value) { 'true' }
      let(:env) { { 'PUMA_CLOUDWATCH_ENABLED' => enabled_value } }

      it 'sets enabled from environment variable' do
        expect(looper.enabled).to eq(enabled_value)
      end
    end

    it 'instantiates a new storage instance with the send frequency' do
      looper

      expect(PumaCloudwatch::Metrics::Storage).to have_received(:new).with(looper.send_frequency)
    end

    it 'creates a new Storage instance' do
      expect(looper.storage).to eq(storage)
    end

    it 'creates a new Sender instance' do
      expect(looper.sender).to eq(sender)
    end

    it 'instantiates a new sender with the send frequency' do
      looper

      expect(PumaCloudwatch::Metrics::Sender).to have_received(:new).with(looper.send_frequency)
    end

    it 'instantiates the parser with the fetcher' do
      looper

      expect(PumaCloudwatch::Metrics::Parser).to have_received(:new).with(fetcher)
    end

    it 'instantiates a new fetcher instance with the options' do
      looper

      expect(PumaCloudwatch::Metrics::Fetcher).to have_received(:new).with(options)
    end

    it 'creates a new Parser instance' do
      expect(looper.parser).to eq(parser)
    end
  end

  describe '#run' do
    let(:fetched_metrics) do
      { 'backlog' => 0, 'running' => 1, 'pool_capacity' => 1, 'max_threads' => 1, 'requests_count' => 0 }
    end
    let(:parsed_metrics) do
      { backlog: [0], pool_capacity: [1], requests_count: [0] }
    end
    let(:extracted_metrics) do
      { Time.now.to_i => { backlog: { min: 0, max: 0, sum: 0.0, samples: 2 },
                           pool_capacity: { min: 1, max: 1, sum: 2.0, samples: 2 },
                           requests_count: { min: 0, max: 0, sum: 0.0, samples: 2 } } }
    end

    before do
      allow(Thread).to receive(:new).and_yield
      allow(looper).to receive(:loop).and_yield
      allow(looper).to receive(:sleep)
      allow(fetcher).to receive(:call).and_return(fetched_metrics)
      allow(parser).to receive(:call).and_return(parsed_metrics)
      allow(storage).to receive(:aggregate)
      allow(storage).to receive(:extract_metrics).and_return(extracted_metrics)
      allow(sender).to receive(:call)
    end

    context 'when not enabled' do
      it 'returns early without creating threads' do
        expect(Thread).not_to have_received(:new)

        looper.run
      end
    end

    context 'when enabled' do
      let(:env) { { 'PUMA_CLOUDWATCH_ENABLED' => 'true' } }

      context 'when control_url is nil' do
        let(:control_url) { nil }

        it 'raises a ControlAppError' do
          expect { looper.run }.to raise_error(described_class::ControlAppError, 'Puma control app is not activated')
        end
      end

      context 'when control_url is present' do
        it 'creates two threads' do
          looper.run

          expect(Thread).to have_received(:new).twice
        end

        context 'when collecting metrics' do
          it 'calls the parser' do
            looper.run

            expect(parser).to have_received(:call)
          end

          it 'calls aggregate on the storage with the parsed metrics' do
            looper.run

            expect(storage).to have_received(:aggregate).with(parsed_metrics)
          end

          it 'sleeps for the collect frequency' do
            looper.run

            expect(looper).to have_received(:sleep).with(looper.collect_frequency)
          end

          context 'when an error occurs' do
            before do
              allow(parser).to receive(:call).and_raise(StandardError.new('parse error'))
              allow(looper).to receive(:puts)
            end

            it 'rescues the error' do
              expect { looper.run }.not_to raise_error
            end

            it 'logs the error' do
              looper.run

              expect(looper).to have_received(:puts).with('PumaCloudwatch Error: parse error (StandardError)')
            end

            context 'when the error is an ENOENT' do
              before do
                allow(parser).to receive(:call).and_raise(Errno::ENOENT.new('no such file or directory'))
              end

              it 'does not log the error' do
                looper.run

                expect(looper).not_to have_received(:puts)
              end
            end
          end
        end

        context 'when sending metrics' do
          before do
            Timecop.freeze(Time.now)
          end

          it 'sleeps for the send frequency' do
            looper.run

            expect(looper).to have_received(:sleep).with(looper.send_frequency)
          end

          it 'calls extract_metrics on the storage with the cutoff time' do
            looper.run

            expect(storage).to have_received(:extract_metrics).with(Time.now.to_f - looper.send_frequency)
          end

          it 'calls the sender with the extracted metrics' do
            looper.run

            expect(sender).to have_received(:call).with(extracted_metrics)
          end

          context 'when no metrics are extracted' do
            let(:extracted_metrics) { {} }

            it 'does not call the sender' do
              looper.run

              expect(sender).not_to have_received(:call)
            end
          end

          context 'when an error occurs' do
            before do
              allow(storage).to receive(:extract_metrics).and_raise(StandardError.new('extract error'))
              allow(looper).to receive(:puts)
            end

            it 'rescues the error' do
              expect { looper.run }.not_to raise_error
            end

            it 'logs the error' do
              looper.run

              expect(looper).to have_received(:puts).with('PumaCloudwatch Error: extract error (StandardError)')
            end
          end
        end
      end
    end
  end
end
