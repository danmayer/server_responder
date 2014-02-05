ENV['RACK_ENV'] = 'test'
require 'sinatra'
require './app'
require 'test/unit'
require 'rack/test'
require 'mocha/setup'

#this var is required for testing
ENV['SERVER_RESPONDER_API_KEY'] ||= 'tester'

class MyAppTest < Test::Unit::TestCase
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def test_root
    get '/'
    assert_match 'Server Responder', last_response.body
  end

  def test_last_job
    get '/last_job'
    assert_match 'last_time', last_response.body
  end

  def test_post_with_bad_api_key_env
    post '/', script_payload.merge(:api_token => 'different_server_key')
    assert_equal "bad api key", last_response.body
  end
  
  def test_process_github_hook_commit__success
    fake_project = {}
    fake_project.expects(:process_github_hook).once
    Project.stubs(:new).returns(fake_project)
    post '/', github_payload.merge('api_token' => ENV['SERVER_RESPONDER_API_KEY'])
  end

  def test_script_payload__success
    app.any_instance.expects(:write_file).with(anything,"9\n").once
    app.any_instance.expects(:reset_artifacts_directory).once
    app.any_instance.expects(:upload_files).once
    File.stubs(:open)
    post '/', script_payload, 'api_token' => ENV['SERVER_RESPONDER_API_KEY']
  end

  private

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
