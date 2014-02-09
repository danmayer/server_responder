ENV['RACK_ENV'] = 'test'
require 'sinatra'
require './app'
require 'test/unit'
require 'rack/test'
require 'mocha/setup'

#this var is required for testing
ENV['SERVER_RESPONDER_API_KEY'] ||= 'tester'

class AppTest < Test::Unit::TestCase
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  protected

  def github_payload
    {:payload => {
        :repository => {
          :url => 'https://github.com/danmayer/server_responder',
          :name => 'server_responder',
          :owner => {
            :name => 'danmayer'
          }
        },
        :after => 'commit_hash'
      }.to_json,
      :api_token =>  ENV['SERVER_RESPONDER_API_KEY']
    }
  end

  def script_payload
    {:payload => {
        :script_payload => 'puts (5+4)',
        :results_location => 'location'
      }.to_json,
      :api_token =>  ENV['SERVER_RESPONDER_API_KEY']
    }
  end

end
