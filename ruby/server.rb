#!/usr/bin/env ruby

require 'jaeger/client'
require 'opentracing'
require 'pry'

$LOAD_PATH.unshift(__dir__)
require 'example_services_pb'
$LOAD_PATH.shift

port = 5555

service_name = 'example/server/ruby'

remote = Jaeger::Reporters::RemoteReporter.new(
  sender: Jaeger::HttpSender.new(
    url: 'http://jaeger:14268/api/traces',
    encoder: Jaeger::Encoders::ThriftEncoder.new(service_name: service_name)
  ),
  flush_interval: 10
)

OpenTracing.global_tracer = Jaeger::Client.build(
  service_name: service_name,
  reporter: Jaeger::Reporters::CompositeReporter.new(
    reporters: [
      Jaeger::Reporters::LoggingReporter.new,
      remote
    ]
  )
)

class Server < Example::Example::Service
  include Example

  def initialize(tracer:)
    @tracer = tracer
  end

  def single(request, call)
    context = tracer.extract(::OpenTracing::FORMAT_TEXT_MAP, call.metadata)

    tracer.start_active_span('single', child_of: context) do
      handle(request)
    end
  end

  def batch(requests, call)
    context = tracer.extract(::OpenTracing::FORMAT_TEXT_MAP, call.metadata)

    tracer.start_active_span('batch', child_of: context) do
      requests.map do |request|
        handle(request)
      end
    end
  end

  private

  attr_reader :tracer

  def handle(request, span=tracer.active_span)
    tracer.start_active_span('handle', child_of: span) do
      sleep(request.message.length * 0.01)
      Response.new(
        message: request.message.reverse
      )
    end
  end
end

server = GRPC::RpcServer.new
server.add_http2_port(
  "0.0.0.0:#{port}",
  :this_port_is_insecure
)

server.handle(
  Server.new(
    tracer: OpenTracing.global_tracer
  )
)

puts "Server listening on #{port}"

server.run_till_terminated_or_interrupted([1, 'int', 'SIGQUIT'])
