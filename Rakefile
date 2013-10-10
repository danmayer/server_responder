require "rubygems"
require 'rake'
require 'rake/testtask'
require 'active_support/core_ext'
require './lib/server_files'

task :default => :test

desc "run tests"
task :test do
  # just run tests, nothing fancy
  Dir["test/**/*.rb"].sort.each { |test|  load test }
end

desc "clear old files, wiping out old S3 files, no longer needed"
task :cleanup_cache do
  include ServerFiles
  destroy_old_files
end
