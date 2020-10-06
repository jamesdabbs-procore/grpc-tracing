#!/usr/bin/env ruby

require 'pry'

class Server

  def call(env)
    puts env["HTTP_AUTHORIZATION"]
    [200, {}, ["foo"]]
  end
end
