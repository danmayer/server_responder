set :public_folder, File.dirname(__FILE__) + '/public'

@@last_push = nil

get '/' do
  @results = `churn`
  @last_push = @@last_push
  erb :index
end

post '/' do
  @push = params
  @@last_push = @push
  erb :index_push
end
