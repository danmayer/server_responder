# encoding: UTF-8
module ServerHelpers

  def tmp_request
    "tmp/last_request.txt"
  end
  
  def tmp_results
    "tmp/last_results.txt"
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
    erb :index_push
  end

  def authorized_client?
    params['api_token'] && params['api_token']==ENV['SERVER_RESPONDER_API_KEY']
  end

  def record_params
    File.open(tmp_request, 'w') {|f| f.write(params.to_json) }
  end

  def record_results(results)
    File.open(tmp_results, 'w') {|f| f.write(results) }
  end

end
