# frozen_string_literal: true

require 'json'
require 'socket'
require 'net/http'
require 'uri'

module PumaCloudwatch
  class Metrics
    # Fetcher is responsible for fetching the stats from the Puma control server
    class Fetcher
      attr_reader :control_url

      def initialize(options = {})
        @control_url = options[:control_url]
        @control_auth_token = options[:control_auth_token]
      end

      def call
        JSON.parse(read_data.split("\n").last) # stats
      end

      private

      attr_reader :control_auth_token

      def read_data
        if @control_url.start_with?('unix://')
          read_socket
        else # starts with tcp://
          read_http
        end
      end

      def read_http
        http_url = control_url.sub('tcp://', 'http://')
        url = "#{http_url}/stats?token=#{control_auth_token}"
        uri = URI.parse(url)
        resp = Net::HTTP.get_response(uri)
        resp.body
      end

      def read_socket
        Socket.unix(control_url.gsub('unix://', '')) do |socket|
          socket.print("GET /stats?token=#{control_auth_token} HTTP/1.0\r\n\r\n")
          socket.read
        end
      end
    end
  end
end
