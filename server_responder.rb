require 'json'

set :public_folder, File.dirname(__FILE__) + '/public'

tmp_file = "tmp/last_request.txt"

get '/' do
  @results = `churn`
  @last_push = File.read(tmp_file)
  erb :index
end

post '/' do
  @push = params
  File.open(tmp_file, 'w') {|f| f.write(@push.to_json) }
  erb :index_push
end
