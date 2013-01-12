require 'sinatra'
require './server_responder'

# This breaks the new passenger setup find new logging option
# log = File.new("log/sinatra.log", "a+")
# STDOUT.reopen(log)
# STDERR.reopen(log)

run Sinatra::Application