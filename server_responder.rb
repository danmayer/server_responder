require 'json'
require 'fog'
require 'fileutils'
require './lib/server-commands'
require './lib/server-files'
require 'rack-ssl-enforcer'
require 'rest_client'
include ServerFiles
include ServerCommands

tmp_file = "tmp/last_request.txt"
tmp_results = "tmp/results.txt"
local_repos = ENV['LOCAL_REPOS'] || "/opt/bitnami/apps/projects/"

  def upload_files(results_location)
    artifact_files = Dir.glob("./artifacts/*")
    puts "files uploading: #{artifact_files.inspect}"
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

# Run me with 'ruby' and I run as a script
if $0 =~ /#{File.basename(__FILE__)}$/
  puts "running as local script"

  #upload_files('batman')
  stop_server

  puts "done"
else
  use Rack::SslEnforcer unless ENV['RACK_ENV']=='test'
  set :public_folder, File.dirname(__FILE__) + '/public'
  set :root, File.dirname(__FILE__)
  enable :logging

  helpers do
    def protected!
      unless authorized?
        response['WWW-Authenticate'] = %(Basic realm="Testing HTTP Auth")
        throw(:halt, [401, "Not authorized\n"])
      end
    end

    def authorized?
      @auth ||=  Rack::Auth::Basic::Request.new(request.env)
      @auth.provided? && @auth.basic? && @auth.credentials && @auth.credentials == ['admin', 'responder']
    end
  end

  before { protected! if request.path_info == "/" && request.request_method == "GET" && ENV['RACK_ENV']!='test' }

  get '/' do
    if File.exists?(tmp_results)
      @results = File.read(tmp_results)
    end
    if File.exists?(tmp_file)
      @last_push = File.read(tmp_file)
      @last_push = @last_push.gsub(/api_token.*:\"#{ENV['SERVER_RESPONDER_API_KEY']}\",/,'api_token":"***",')
    end
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
    local_repos = ENV['LOCAL_REPOS'] || "/opt/bitnami/apps/projects/"
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
      cmd = "churn"
      if File.exists?(deferred_server_config)
        cmd = File.read(deferred_server_config)
        results = nil
        Dir.chdir(repo_location) do
          if File.exists?("#{repo_location}/Gemfile")
            `chmod +w Gemfile.lock`
            `gem install bundler --no-ri --no-rdoc`
            `BUNDLE_GEMFILE=#{repo_location}/Gemfile && bundle install`
          end
          full_cmd = "BUNDLE_GEMFILE=#{repo_location}/Gemfile && #{cmd}"
          logger.info "dir: #{repo_location} && running: #{full_cmd}"
          results = `#{full_cmd} 2>&1`
        end
      else
        results = `cd #{repo_location}; #{cmd}`
      end
      #temporary hack for the empty results not creating files / valid output
      if results==''
        results = 'script completed with no output'
      end
      puts "results: #{results}"
      exit_status = $?.exitstatus
      json_results = {
        :cmd_run     => cmd,
        :exit_status => exit_status,
        :results     => results
      }
      write_file(commit_key,json_results.to_json)
      write_commits(project_key, after_commit, commit_key, push)
    end
    RestClient.post "http://git-hook-responder.herokuapp.com"+"/request_complete",
    {:project_key => project_key, :commit_key => commit_key}

    results
  end

  def script_payload(push)
    logger.info "running script_payload"
    script_payload = push['script_payload']
    results_location = push['results_location']
    if script_payload && results_location
      script_payload = script_payload.gsub("\"","\\\"")
      reset_artifacts_directory
      logger.info "running: #{script_payload}"
      results = `ruby -e "#{script_payload}"`
      #temporary hack for the empty results not creating files / valid output
      if results==''
        results = 'script completed with no output'
      end
      logger.info "results: #{results}"
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

  private

  def debug_env
    puts `which ruby`
    puts `which gem`
    puts `gem env`
    puts `gem list --local`
    #puts `rvm`
    puts `whoami`
    puts `echo $PATH`
    puts `which bundle`
    puts `pwd`
  end

end
