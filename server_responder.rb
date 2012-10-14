require 'json'
require 'fog'
require './lib/server-commands'
require './lib/server-files'
include ServerFiles
include ServerCommands

tmp_file = "tmp/last_request.txt"
tmp_results = "tmp/results.txt"
local_repos = ENV['LOCAL_REPOS'] || "/opt/bitnami/apps/projects/"

# Run me with 'ruby' and I run as a script
if $0 =~ /#{File.basename(__FILE__)}$/
  puts "running as local script"

  stop_server

  puts "done"
else
  set :public_folder, File.dirname(__FILE__) + '/public'

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

  post '/' do
    File.open(tmp_file, 'w') {|f| f.write(params.to_json) }
    push = JSON.parse(params['payload'])
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
      results = `cd #{repo_location}; churn`

      write_file(commit_key,results)
      write_commits(project_key, after_commit, commit_key)

      File.open(tmp_results, 'w') {|f| f.write(results) }
    end
    erb :index_push
  end
end
