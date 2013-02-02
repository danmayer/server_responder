require 'json'
require 'fog'
require './lib/server-commands'
require './lib/server-files'
include ServerFiles
include ServerCommands

tmp_file = "tmp/last_request.txt"
tmp_results = "tmp/results.txt"
local_repos = ENV['LOCAL_REPOS'] || "/opt/bitnami/apps/projects/"

  def upload_files(results_location)
    artifact_files = Dir.glob("./artifacts/*")
    puts artifact_files.inspect
    if artifact_files.length > 0
      write_file(results_location+'_artifact_files',artifact_files.map{|f| 'https://s3.amazonaws.com/deferred-server/'+results_location+'_artifact_files_'+f.to_s.gsub('/','_')}.to_json)
      artifact_files.each do |file|
        write_file(results_location+'_artifact_files_'+file.to_s.gsub('/','_'), File.read(file))
      end
    end
  end

  def reset_artifacts_directory
    FileUtils.rm_rf('./artifacts', :secure => true)
    Dir.mkdir('./artifacts') unless File.exists?('./artifacts')
  end

# Run me with 'ruby' and I run as a script
if $0 =~ /#{File.basename(__FILE__)}$/
  puts "running as local script"

  #upload_files('batman')
  stop_server

  puts "done"
else
  # This breaks the new passenger setup find new logging option
  log = File.new("log/sinatra.log", "a+")
  STDOUT.reopen(log)
  STDERR.reopen(log)

  set :public_folder, File.dirname(__FILE__) + '/public'
  set :root, File.dirname(__FILE__)

  get '/' do
    @results = File.read(tmp_results) if File.exists?(tmp_results)
    @last_push = File.read(tmp_file) if File.exists?(tmp_file)
    erb :index
  end

  get '/last_job' do
    last_job_time = if File.exists?(tmp_file)
      File.mtime(tmp_file)
    else
      Time.now
    end
    {:last_time => last_job_time}.to_json
  end

  def github_hook_commit(push)
    repo_url = push['repository']['url'] rescue nil
    repo_name = push['repository']['name'] rescue nil
    user = push['repository']['owner']['name'] rescue nil
    after_commit = push['after']
    project_key  = "#{user}/#{repo_name}"
    commit_key   = "#{project_key}/#{after_commit}"
    logger.info("repo_url: #{repo_url}")

    if repo_url && repo_name
      repo_location = "#{local_repos}#{repo_name}"
      if File.exists?(repo_location)
        logger.info("update repo")
        `cd #{repo_location}; git pull`
      else
        logger.info("create repo")
        `cd #{local_repos}; git clone #{repo_url}`
      end
      deferred_server_config = "#{repo_location}/.deferred_server"
      if File.exists?(deferred_server_config)
        cmd = File.read(deferred_server_config)
        results = nil
        Dir.chdir(repo_location) do
          results = `cd #{repo_location}`
          logger.info "chdir: #{results}"
          results = `pwd`
          logger.info "pwd: #{results}"
          full_cmd = "cd #{repo_location} && BUNDLE_GEMFILE=#{repo_location}/Gemfile && #{cmd}"
          logger.info "dir: #{repo_location} && running: #{full_cmd}"
          results = `#{full_cmd}`
        end
      else
        results = `cd #{repo_location}; churn`
      end
      #temporary hack for the empty results not creating files / valid output
      if results==''
        results = 'script completed with no output'
      end

      write_file(commit_key,results)
      write_commits(project_key, after_commit, commit_key)
    end
    results
  end

  def script_payload(push)
    script_payload = push['script_payload']
    results_location = push['results_location']
    if script_payload && results_location
      script_payload = script_payload.gsub("\"","\\\"")
      logger.info "running: #{script_payload}"
      reset_artifacts_directory
      results = `ruby -e "#{script_payload}"`
      write_file(results_location,results)
      upload_files(results_location)
      results
    end
  end

  post '/' do
    if params['api_token'] && params['api_token']==ENV['SERVER_RESPONDER_API_KEY']
      begin
        File.open(tmp_file, 'w') {|f| f.write(params.to_json) }
        push = JSON.parse(params['payload'])
        results = if push['script_payload']
                    script_payload(push)
                  else
                    github_hook_commit(push)
                  end

        File.open(tmp_results, 'w') {|f| f.write(results) }
        erb :index_push
      rescue => error
        logger.error "hit post error #{error.inspect}\n #{error.backtrace}"
        raise error
      end
    else
      logger.error "received a invalid request"
      "bad api key"
    end
  end
end
