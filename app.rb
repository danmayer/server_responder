# encoding: UTF-8
require 'json'
require 'fileutils'
require 'rack-ssl-enforcer'
require 'rest_client'
require 'systemu'
require 'active_support/core_ext'
require 'airbrake'
require 'logstash-logger'
require 'sinatra/cross_origin'

require './lib/server_files'
require './lib/server_helpers'
require './lib/project_commands'
require './lib/code-signing'
require './lib/rack_catcher'
require './lib/swagger_handlers'

include CodeSigning
include ServerFiles
include ServerHelpers

ADMIN_PASSWORD = ENV['SERVER_RESPONDER_ADMIN_PASS'] || 'default_password'

use Rack::SslEnforcer if ENV['RACK_ENV']=='production'
set :public_folder, File.dirname(__FILE__) + '/public'
set :root, File.dirname(__FILE__)
enable :logging

configure :development do
  require "better_errors"
  use BetterErrors::Middleware
  BetterErrors.application_root = File.dirname(__FILE__)
end

configure :production do
  Airbrake.configure do |config|
    config.api_key = ENV['SR_ERRBIT_API_KEY']
    config.host    = ENV['ERRBIT_HOST']
    config.port    = 80
    config.secure  = config.port == 443
  end
  use Rack::Catcher
  use Airbrake::Rack
  set :raise_errors, true
end

def logger
  @@logger ||= if ENV['LOGGER_HOST'] && ENV['RACK_ENV']!='test'
                 LogStashLogger.new(ENV['LOGGER_HOST'], 49175, :tcp)
               else
                 Logger.new("sinatra.log")
               end
end

helpers do
  def protected!
    unless authorized?
      response['WWW-Authenticate'] = %(Basic realm="Testing HTTP Auth")
      throw(:halt, [401, "Not authorized\n"])
    end
  end

  def authorized?
    @auth ||=  Rack::Auth::Basic::Request.new(request.env)
    @auth.provided? && @auth.basic? && @auth.credentials && @auth.credentials == ['admin', ADMIN_PASSWORD]
  end
end

before { protected! if request.path_info == "/admin" && request.request_method == "GET" && ENV['RACK_ENV']!='test' }

##~ swaggerBase = "http://localhost:9292"
##~ root = source2swagger.namespace("api-docs")
##~ root.swaggerVersion = "1.2"
##~ root.apiVersion = "1.0"
##~ root.info = {title: "Server Responder API", description: "This api generates responses from a given project using a throw away server.", termsOfServiceUrl: "https://github.com/danmayer/server_responder/blob/master/license.txt", contact: "danmayer@gmail.com", license: "MIT", licenseUrl: "https://github.com/danmayer/server_responder/blob/master/license.txt"}
##~ root.apis.add :path => "/serverresponder", :description => "Generic Server Responder Api"

##~ s = source2swagger.namespace("serverresponder")
##~ s.basePath =  swaggerBase
##~ s.swaggerVersion = "1.2"
##~ s.apiVersion = "1.0"
##~ s.produces = ["application/json"]
##~ s.resourcePath = "/index"

## models
##~ s.models["Service"] = {:id => "Service", :properties => {:name => {:type => "string"}, :project_url => {:type => "string"}}}
##~ s.models["LastJob"] = {:id => "LastJob", :properties => {:last_time => {:type => "string"}}}
include SwaggerHandlers

##~ a = s.apis.add
##~ a.set :path => "/index", :produces => ["application/json"], :description => "Collection of available services"
##
##~ op = a.operations.add
##~ op.type = "array"
##~ op.items = { "$ref" => "Service"}
##
##~ op.set :method => "GET", :summary => "Returns all available services.", :deprecated => false, :nickname => "list"
##~ op.summary = "Returns a list of all the available services"
get '/index' do
  [].to_json
end

get '/' do
  erb :index
end

get '/admin' do
  @results = last_results
  @last_push = last_push_request
  erb :admin
end

get '/example' do
  erb :example
end

##~ a = s.apis.add
##~ a.set :path => "/last_job", :produces => ["application/json"], :description => "The time the last job was completed on this server responder instance"
##
##~ op = a.operations.add
##~ op.type = "LastJob"
##
##~ op.set :method => "GET", :summary => "Returns the time the last job was completed", :deprecated => false, :nickname => "last_job"
##~ op.summary = "Returns the time the last job was completed"
get '/last_job' do
  {:last_time => last_job_time}.to_json
end

def process_github_hook_commit(push)
  repo_url = push['repository']['url'] rescue nil
  repo_name = push['repository']['name'] rescue nil
  user = push['repository']['owner']['name'] rescue nil
  after_commit = push['after']
  project_key  = "#{user}/#{repo_name}"
  commit_key   = "#{project_key}/#{after_commit}"
  logger.info("process_github_hook_commit repo_url: #{repo_url}")  

  project = Project.new(:name => repo_name, :user => user, :url => repo_url, :commit => after_commit, :repos_dir => default_local_location, :results_location => nil, :push => push, :logger => logger)
  project.process_github_hook
end

def process_project_cmd_payload(push)
  results_location = push['results_location']
  repo_name = push['project'] rescue nil
  commit    = push['commit']
  cmd       = params['command'] || push['command'] || "churn --yaml"
  repo_url  = "https://github.com/#{repo_name}"
  user      = repo_name.split('/').first
  repo_name = repo_name.split('/').last
  logger.info("process_project_cmd_payload repo_url: #{repo_url}")
  
  project = Project.new(:name => repo_name, :user => user, :url => repo_url, :commit => commit, :repos_dir => default_local_location, :results_location => results_location, :logger => logger)
  project.process_cmd(cmd)
end

def process_project_request_payload(push)
  project = push['project']
  user_name = project.split('/')[0]
  repo_name = project.split('/')[1]
  project_request = push['project_request']
  results_location = push['results_location']
  repo_url  = "https://github.com/#{project}"
  commit = "HEAD"
  logger.info "running project_request_payload #{project}"

  project = Project.new(:name => repo_name, :user => user_name, :url => repo_url, :commit => commit, :repos_dir => default_local_location, :results_location => results_location, :logger => logger)
  project.process_request(project_request)
end

def process_script_payload(push)
  script_payload = push['script_payload']
  results_location = push['results_location']
  logger.info "running process_script_payload #{script_payload} and #{results_location}"
  if script_payload && results_location
    script_payload = script_payload.gsub("\"","\\\"")
    reset_artifacts_directory
    logger.info "running: #{script_payload}"
    results = `ruby -e "#{script_payload}"`
    if results==''
      results = 'script completed with no output'
    end
    logger.info "results: #{results}"
    write_file(results_location,results)
    upload_files(results_location)
    results
  end
end

##~ a = s.apis.add
##~ a.set :path => "/process/script", :produces => ["application/json"], :description => "This processes the rubyscript and returns the results as well as stores assets"
##
##~ op = a.operations.add
##~ op.type = "String"
##
##~ op.set :method => "POST", :summary => "This processes the rubyscript and returns the results as well as stores assets", :deprecated => false, :nickname => "process_script"
##~ op.summary = "This processes the rubyscript and returns the results as well as stores assets"

def process_request
  record_params
  push = JSON.parse(params['payload'])
  results = if push['script_payload']
              process_script_payload(push)
            elsif(push['project'] && push['project_request'])
              process_project_request_payload(push)
            elsif(push['project'] && push['command'])
              process_project_cmd_payload(push)
            else
              process_github_hook_commit(push)
            end
  
  record_results(results)
  {'results' => results}.to_json
end

post '/' do
  unless authorized_client?
    logger.error "received a invalid request"
    "bad api key"#, :status => 503
  else    
    begin
      process_request
    rescue => error
      logger.error "error processing post to root with params #{params.inspect} error #{error.inspect}\n #{error.backtrace}"
      raise error
    end
  end
end
