# encoding: UTF-8
module ServerHelpers
  @@last_accessed = nil
  @@tmp_results = nil
  @@tmp_request = nil

  def last_job_time
    @@last_accessed || Time.now
  end

  def last_results
    @@tmp_results || 'no results yet'
  end

  def last_push_request
    if @@tmp_request
      last_push = tmp_request
      last_push = last_push.gsub(/api_token.*:\"#{ENV['SERVER_RESPONDER_API_KEY']}\",/,'api_token":"***",')
    end
  end

  def upload_files(results_location)
    artifact_files = Dir.glob("./artifacts/*")
    logger.info "files uploading: #{artifact_files.inspect}"
    if artifact_files.length > 0
      write_file(results_location+'_artifact_files',artifact_files.map{|f| 'https://s3.amazonaws.com/deferred-server/'+results_location+'_artifact_files_'+f.to_s.gsub('/','_')}.to_json)
      artifact_files.each do |file|
        mimetype = `file -Ib #{file}`.gsub(/\n/,"")
        write_file(results_location+'_artifact_files_'+file.to_s.gsub('/','_'), File.read(file), :content_type => mimetype)
      end
    end
  end

  def reset_artifacts_directory
    FileUtils.rm_rf('./artifacts', :secure => false)
    Dir.mkdir('./artifacts') unless File.exists?('./artifacts')
    artifact_files = Dir.glob("./artifacts/*")
    puts "files after clearing: #{artifact_files.inspect}"
  end

  def default_local_location
    ENV['LOCAL_REPOS'] || "/opt/bitnami/apps/projects/"
  end

  def process_request
    record_params
    push = JSON.parse(params['payload'])
    results = if push['script_payload']
                process_script_payload(push)
              elsif(push['project'] && push['project_request'])
                process_project_request_payload(push)
              elsif(push['project'] && push['command'])
                process_project_cmd_payload(push)
              else
                process_github_hook_commit(push)
              end
    
    record_results(results)
    {'results' => results}.to_json
  end

  def authorized_client?
    (params['api_token'] && params['api_token']==ENV['SERVER_RESPONDER_API_KEY'] ||
     params['signature'] && params['payload'] && params['signature']==code_signature(JSON.parse(params['payload'])['script_payload']))
  end

  private

  def record_params
    @@last_accessed = Time.now
    @@tmp_request = params.to_json
  end

  def record_results(results)
    @@tmp_results = results
  end

end
