#!/usr/bin/env ruby

require 'jaeger/client'
require 'opentracing'
require 'pry'
require 'securerandom'

$LOAD_PATH.unshift(__dir__)
require 'example_services_pb'
$LOAD_PATH.shift

iterations = Integer(ARGV.shift || '3')

service_name = 'example/client/ruby'

remote = Jaeger::Reporters::RemoteReporter.new(
  sender: Jaeger::HttpSender.new(
    url: 'http://jaeger:14268/api/traces',
    encoder: Jaeger::Encoders::ThriftEncoder.new(service_name: service_name)
  ),
  flush_interval: 1
)
tracer = OpenTracing.global_tracer = Jaeger::Client.build(
  service_name: service_name,
  reporter: Jaeger::Reporters::CompositeReporter.new(
    reporters: [
      # Jaeger::Reporters::LoggingReporter.new,
      remote
    ]
  ),
  injectors: {
    OpenTracing::FORMAT_TEXT_MAP => [Jaeger::Injectors::B3RackCodec, Jaeger::Injectors::JaegerTextMapCodec]
  }
)

stub = Example::Example::Stub.new('client-proxy:8000', :this_channel_is_insecure)

requests = %w[first second third].map do |word|
  Example::Request.new(message: word)
end

iterations.times do
  puts '=> singles'
  metadata = {}
  tracer.start_active_span('singles') do
    requests.each do |request|
      tracer.start_active_span('single') do
        tracer.inject(tracer.active_span.context, ::OpenTracing::FORMAT_TEXT_MAP, metadata)
        puts metadata.inspect
        puts stub.single(request, metadata: metadata).message
      end
    end
  end

  puts '=> batch'
  metadata = {}
  tracer.start_active_span('batch', tags: metadata) do
    tracer.inject(tracer.active_span.context, ::OpenTracing::FORMAT_TEXT_MAP, metadata)
    puts metadata.inspect
    stub.batch(requests, metadata: metadata) do |response|
      puts response.message
    end
  end
end

sleep 2 # flush the last spans
