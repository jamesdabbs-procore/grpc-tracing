#!/usr/bin/env ruby

require 'jaeger/client'
require 'opentracing'
require 'pry'
require 'securerandom'

$LOAD_PATH.unshift(__dir__)
require 'example_services_pb'
$LOAD_PATH.shift

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
  )
)

stub = Example::Example::Stub.new('server-proxy:8000', :this_channel_is_insecure)

requests = %w[first second third].map do |word|
  Example::Request.new(message: word)
end

4.times do
  puts '=> singles'
  tracer.start_active_span('singles', tags: { 'request_id' => SecureRandom.uuid }) do
    requests.each do |request|
      tracer.start_active_span('single') do
        metadata = {}
        tracer.inject(tracer.active_span.context, ::OpenTracing::FORMAT_TEXT_MAP, metadata)
        puts stub.single(request, metadata: metadata).message
      end
    end
  end

  puts '=> batch'
  tracer.start_active_span('batch', tags: { 'request_id' => SecureRandom.uuid }) do
    metadata = {}
    tracer.inject(tracer.active_span.context, ::OpenTracing::FORMAT_TEXT_MAP, metadata)
    stub.batch(requests, metadata: metadata) do |response|
      puts response.message
    end
  end
end

sleep 2 # flush the last spans
