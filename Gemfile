source :rubygems
gem 'rake'
gem 'sinatra'
gem 'churn'
gem 'json'
gem 'fog'

# Prevent installation on Heroku with
# heroku config:add BUNDLE_WITHOUT="development:test"
group :development, :test do
#  gem 'ruby-debug19', :require => 'ruby-debug'
   gem 'rack-test'
end

if RbConfig::CONFIG['host_os'] =~ /darwin/
  group :development do
    gem 'thin'
    gem 'pry'
  end
end