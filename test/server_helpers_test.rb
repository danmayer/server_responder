require_relative 'test_helper'

class ServerHelpersTest < AppTest

  def test_reset_artifacts_directory
    FileUtils.expects(:rm_rf).once
    File.expects(:exists?).once.returns(false)
    Dir.expects(:mkdir).once
    app.reset_artifacts_directory
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

  def test_default_local_location__nothing_set
    assert_equal "/opt/bitnami/apps/projects/", app.default_local_location
  end
  
  def test_default_local_location__env_set
    previous_setting = ENV['LOCAL_REPOS']
    begin
      ENV['LOCAL_REPOS'] = 'test'
      assert_equal "test", app.default_local_location
    ensure
      ENV['LOCAL_REPOS'] = previous_setting
    end
  end

end
