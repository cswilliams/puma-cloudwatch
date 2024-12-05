# Puma Cloudwatch Plugin

A [puma](https://puma.io) plugin that sends puma stats to CloudWatch.

This is a fork of the [puma-cloudwatch](https://github.com/boltops-tools/puma-cloudwatch) gem with the following changes:

1. Split the collection and sending of metrics into two separate threads. This allows you to collect metrics more frequently than you send them to CloudWatch. This is configured via two new environment variables: `PUMA_CLOUDWATCH_COLLECT_FREQUENCY` and `PUMA_CLOUDWATCH_SEND_FREQUENCY`. This allows you to collect metrics more frequently than you send them to CloudWatch. For example, you can collect metrics every 1-5s and send them to CloudWatch every 60s.

2. Changed the reported metrics to: `pool_capacity`, `backlog`, and `requests_count`. 

3. I've removed some features that I didn't need like the debug mode, custom dimensions, and custom AWS creds to make the code simpler. I also changed the default namespace to `Puma` instead of `Webserver`.

4. Some misc code cleanup and refactoring

5. I've made the specs more rigorous with 100% coverage, including an integration test that spins up a puma server and tests the plugin.

## Usage

List of metrics reported to cloudwatch:

* pool_capacity: the number of idle and unused worker threads. When this is low/zero, puma is running at full capacity and might need scaling up
* backlog: the number of requests that have made it to a worker but are yet to be processed. This will normally be zero, as requests queue on the tcp/unix socket in front of the master puma process, not in the worker thread pool
* requests_count: incrementing count of handled requests


### Environment Variables

The plugin's settings can be controlled with environmental variables:

Env Var | Description | Default Value
--- | --- | ---
PUMA\_CLOUDWATCH\_ENABLED | Enables sending of the data to CloudWatch. | (unset)
PUMA\_CLOUDWATCH\_SEND_FREQUENCY | How often to send data to CloudWatch in seconds. | 60
PUMA\_CLOUDWATCH\_COLLECT_FREQUENCY | How often to collect data from Puma in seconds. | 5
PUMA\_CLOUDWATCH\_NAMESPACE | CloudWatch metric namespace | Puma

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'puma-cloudwatch', git: 'https://github.com/cswilliams/puma-cloudwatch'
```

And then execute:

    $ bundle

Add these 2 lines your `config/puma.rb`:

config/puma.rb

```ruby
activate_control_app
plugin :cloudwatch
```

It activates the puma control rack application, and enables the puma-cloudwatch plugin to send metrics.

## How It Works: Internal Puma Stats Server

Puma has an internal server that has a stats endpoint. It runs on a unix socket by default. The puma-cloudwatch works by running continuous loop that polls this puma socket.