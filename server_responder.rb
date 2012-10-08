require 'json'
require 'fog'
require './lib/server-files'
include ServerFiles

set :public_folder, File.dirname(__FILE__) + '/public'

tmp_file = "tmp/last_request.txt"
tmp_results = "tmp/results.txt"
local_repos = ENV['LOCAL_REPOS'] || "/opt/bitnami/apps/projects/"

get '/' do
  @results = File.read(tmp_results) if File.exists?(tmp_results)
  @last_push = File.read(tmp_file) if File.exists?(tmp_file)
  erb :index
end

post '/' do
  File.open(tmp_file, 'w') {|f| f.write(params.to_json) }
  push = JSON.parse(params['payload'])
  repo_url = push['repository']['url'] rescue nil
  repo_name = push['repository']['name'] rescue nil
  user = push['repository']['owner']['name'] rescue nil
  project_key = "#{user}/#{repo_name}"
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
    write_file(project_key,results)
    File.open(tmp_results, 'w') {|f| f.write(results) }
  end
  erb :index_push
end
