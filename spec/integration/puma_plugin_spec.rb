# frozen_string_literal: true

require 'tempfile'
require 'puma'
require 'puma/configuration'
require 'puma/events'
require 'puma/launcher'
require 'securerandom'

RSpec.describe 'Puma Plugin Integration' do # rubocop:disable RSpec/DescribeClass
  let(:control_token) { SecureRandom.hex(16) }
  let(:control_port) { rand(10_000..65_000) }
  let(:control_url) { "tcp://127.0.0.1:#{control_port}" }

  let(:config_file) do
    Tempfile.new(['puma_config', '.rb']).tap do |f|
      f.write(<<~CONFIG)
        plugin 'cloudwatch'
        port 0 # Use port 0 to let the OS assign a random port
        workers 0
        threads 1,1
        activate_control_app '#{control_url}', { auth_token: '#{control_token}' }
        app do |_env|
          [200, {}, ['OK']]
        end
      CONFIG
      f.close
    end
  end

  let(:events) { Puma::Events.new }
  let(:config) do
    Puma::Configuration.new do |_, file_config, _|
      file_config.load config_file.path
    end
  end
  let(:launcher) { Puma::Launcher.new(config, events:) }
  let(:launcher_thread) { Thread.new { launcher.run } }
  let(:collect_frequency) { 1 }
  let(:send_frequency) { 3 }
  let(:env) do
    {
      'PUMA_CLOUDWATCH_COLLECT_FREQUENCY' => collect_frequency,
      'PUMA_CLOUDWATCH_SEND_FREQUENCY' => send_frequency,
      'PUMA_CLOUDWATCH_ENABLED' => 'true'
    }
  end
  let(:cloudwatch_client) { instance_double(Aws::CloudWatch::Client) }

  before do
    allow($stdout).to receive(:write)
    allow(Aws::CloudWatch::Client).to receive(:new).and_return(cloudwatch_client)
    allow(cloudwatch_client).to receive(:put_metric_data)
    launcher_thread
    sleep 0.5 # Wait for Puma to start
    sleep send_frequency * 2 # Wait for metrics to be sent
    PumaCloudwatch::Metrics.stop_sending
    launcher&.stop
    launcher_thread.join
    config_file.unlink
    sleep 1 # Wait for Puma to stop
  end

  it 'collects and sends metrics to CloudWatch' do
    aggregate_failures do
      expect(cloudwatch_client).to have_received(:put_metric_data).at_least(:once).times do |params|
        expect(params[:namespace]).to eq(PumaCloudwatch::Metrics::Sender::DEFAULT_NAMESPACE)
        expect(params[:metric_data]).to be_an(Array)
        expect(params[:metric_data].size).to eq(PumaCloudwatch::Metrics::Parser::METRICS.size)
        requests_count = params[:metric_data].find { |m| m[:metric_name] == 'requests_count' }
        expect(requests_count[:storage_resolution]).to eq(1)
        expect(requests_count[:statistic_values].keys).to contain_exactly(:sample_count, :sum, :minimum, :maximum)
        expect(requests_count[:statistic_values][:minimum]).to eq(0)
        expect(requests_count[:statistic_values][:maximum]).to eq(0)
        expect(requests_count[:timestamp]).to be_a(Time)
      end
    end
  end
end
