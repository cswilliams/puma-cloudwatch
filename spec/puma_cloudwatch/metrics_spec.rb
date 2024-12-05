# frozen_string_literal: true

RSpec.describe PumaCloudwatch::Metrics do
  let(:options) { { key: 'value' } }
  let(:launcher) { instance_double(Puma::Launcher, options:) }
  let(:looper) { instance_double(PumaCloudwatch::Metrics::Looper) }

  describe '.start_sending' do
    subject(:start_sending) { described_class.start_sending(launcher) }

    before do
      allow(PumaCloudwatch::Metrics::Looper).to receive(:new).and_return(looper)
      allow(looper).to receive(:run)

      start_sending
    end

    it 'instantiates a new looper with the launcher options' do
      expect(PumaCloudwatch::Metrics::Looper).to have_received(:new).with(launcher.options)
    end

    it 'runs the looper' do
      expect(looper).to have_received(:run)
    end

    it 'stores the looper' do
      expect(described_class.instance_variable_get(:@looper)).to eq(looper)
    end
  end

  describe '.stop_sending' do
    subject(:stop_sending) { described_class.stop_sending }

    before do
      described_class.instance_variable_set(:@looper, looper)
      allow(looper).to receive(:stop)

      stop_sending
    end

    it 'stops the looper' do
      expect(looper).to have_received(:stop)
    end
  end
end
