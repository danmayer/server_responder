require 'json'

set :public_folder, File.dirname(__FILE__) + '/public'

tmp_file = "tmp/last_request.txt"
local_repos = ENV['LOCAL_REPOS'] || "/opt/bitnami/apps/"

get '/' do
  @results = `churn`
  @last_push = File.read(tmp_file) if File.exists?(tmp_file)
  erb :index
end

post '/' do
  @push = params
  File.open(tmp_file, 'w') {|f| f.write(@push.to_json) }
  repo_url = params['payload']['repository']['url'] rescue nil
  repo_name = params['payload']['repository']['name'] rescue nil
  if repo_url && repo_name
    repo_location = "#{local_repos}#{local_repos}"
    if File.exists?(repo_location)
      `cd #{repo_location}; git pull`
    else
      `cd #{local_repos}; git clone #{repo_url}`
    end
  end
  erb :index_push
end
