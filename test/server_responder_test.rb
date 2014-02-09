require_relative 'test_helper'

class ServerResponderTest < AppTest

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

  def test_authorized_client__token
    app.stubs(:params).returns({'api_token' => ENV['SERVER_RESPONDER_API_KEY']})
    assert_equal true, app.authorized_client?
  end

  def test_authorized_client__signature
    app.stubs(:code_signature).returns('sig')
    app.stubs(:params).returns({'signature' => 'sig', 'payload' => {'script_payload' => 'script'}.to_json})
    assert_equal true, app.authorized_client?
  end

end
