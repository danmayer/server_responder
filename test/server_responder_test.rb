ENV['RACK_ENV'] = 'test'
require 'sinatra'
require 'server_responder'
require 'test/unit'
require 'rack/test'
require 'mocha/setup'

class MyAppTest < Test::Unit::TestCase
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def test_root
    get '/'
    assert_match 'last results', last_response.body
    assert_match 'last push', last_response.body
    assert_match 'debug info', last_response.body
  end

  def test_last_job
    get '/last_job'
    assert_match 'last_time', last_response.body
  end

  def test_script_payload__success
    app.any_instance.expects(:write_file).with(anything,"9\n").once
    app.any_instance.expects(:reset_artifacts_directory).once
    app.any_instance.expects(:upload_files).once
    File.stubs(:open)
    post '/', script_payload, 'SERVER_RESPONDER_API_KEY' => ENV['SERVER_RESPONDER_API_KEY']
  end

  def test_post_with_bad_api_key_env
    post '/', script_payload.merge(:api_token => 'different_server_key')
    assert_equal "bad api key", last_response.body
  end

  private

  def script_payload
    {:payload => {
        :script_payload => 'puts (5+4)',
        :results_location => 'location'
      }.to_json,
      :api_token =>  ENV['SERVER_RESPONDER_API_KEY']
    }
  end

end
