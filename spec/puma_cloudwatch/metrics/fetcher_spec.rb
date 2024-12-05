# frozen_string_literal: true

RSpec.describe PumaCloudwatch::Metrics::Fetcher do
  subject(:fetcher) { described_class.new(control_url:, control_auth_token:) }

  let(:response) { { 'workers' => 2, 'booted_workers' => 2, 'running' => 0 } }
  let(:control_auth_token) { 'secret-token' }
  let(:control_url) { 'unix:///tmp/puma.sock' }

  describe '#call' do
    context 'with unix socket' do
      let(:stringio) { instance_double(StringIO, print: nil, read: "\n#{JSON.dump(response)}") }

      before do
        allow(Socket).to receive(:unix).and_yield(stringio)
      end

      it 'fetches stats via unix socket' do
        fetcher.call

        expect(Socket).to have_received(:unix).with('/tmp/puma.sock')
      end

      it 'calls print on the endpoint with the token' do
        fetcher.call

        expect(stringio).to have_received(:print).with("GET /stats?token=#{control_auth_token} HTTP/1.0\r\n\r\n")
      end

      it 'returns parsed JSON response' do
        stats = fetcher.call

        expect(stats).to eq(response)
      end
    end

    context 'with HTTP endpoint' do
      let(:control_url) { 'tcp://localhost:9293' }
      let(:expected_uri) { URI.parse("#{control_url.gsub('tcp://', 'http://')}/stats?token=#{control_auth_token}") }

      let(:http_response) { instance_double(Net::HTTPResponse, body: JSON.dump(response)) }

      before do
        allow(Net::HTTP).to receive(:get_response).and_return(http_response)
      end

      it 'fetches stats via HTTP at the correct url' do
        fetcher.call

        expect(Net::HTTP).to have_received(:get_response).with(expected_uri)
      end

      it 'returns parsed JSON response' do
        stats = fetcher.call
        expect(stats).to eq(response)
      end
    end
  end

  describe '#initialize' do
    it 'sets the control url from the passed in options' do
      expect(fetcher.control_url).to eq(control_url)
    end

    it 'sets the control auth token from the passed in options' do
      expect(fetcher.instance_variable_get(:@control_auth_token)).to eq(control_auth_token)
    end
  end
end
