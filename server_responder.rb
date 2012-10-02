require 'json'

set :public_folder, File.dirname(__FILE__) + '/public'

tmp_file = "tmp/last_request.txt"
tmp_results = "tmp/results.txt"
local_repos = ENV['LOCAL_REPOS'] || "/opt/bitnami/apps/projects"

get '/' do
  @results = File.read(tmp_results) if File.exists?(tmp_results)
  @last_push = File.read(tmp_file) if File.exists?(tmp_file)
  erb :index
end

post '/' do
  @push = params
  File.open(tmp_file, 'w') {|f| f.write(@push.to_json) }
  repo_url = JSON.parse(params['payload'])['repository']['url'] rescue nil
  repo_name = JSON.parse(params['payload'])['repository']['name'] rescue nil
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
    File.open(tmp_results, 'w') {|f| f.write(results) }
  end
  erb :index_push
end
