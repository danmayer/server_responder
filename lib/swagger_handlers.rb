module SwaggerHandlers
  # redict to documentation index file
  get '/docs/?' do
    redirect '/docs/index.html'
  end
  
  # returns the api docs for the resource listing
  get '/api-docs/?', :provides => [:json] do
    res = File.read(File.join('public', 'api', 'api-docs.json'))
    body res
    status 200
  end
  
  # returns the api docs for each path
  get '/api-docs/:api', :provides => [:json] do
    if File.exists?(File.join('public', 'api', "#{params[:api].to_s}.json"))
      res = File.read(File.join('public', 'api', "#{params[:api].to_s}.json"))
      body res
      status 200
    else
      body = "api endpoint doesn't exist"
      status 404
    end
  end
end
