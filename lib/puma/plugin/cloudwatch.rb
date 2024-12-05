# frozen_string_literal: true

require 'puma_cloudwatch'

Puma::Plugin.create do
  def start(launcher)
    PumaCloudwatch::Metrics.start_sending(launcher)
  end
end
