# encoding: UTF-8
class Project
  include ServerFiles

  OPTIONAL_OPTIONS = [:results_location]
  REQUIRED_OPTIONS = [:name, :url, :commit, :user, :repos_dir, :logger]
  PAYLOAD_PORT = 4005

  attr_accessor *(REQUIRED_OPTIONS+OPTIONAL_OPTIONS)

  def initialize(opts = {})
    name             = opts[:name]
    url              = opts[:url]
    commit           = opts[:commit]
    user             = opts[:user]
    repos_dir        = opts[:repos_dir]
    results_location = opts[:results_location]
    logger           = opts[:logger] || Logger.new("sinatra.log")
    if REQUIRED_OPTIONS.any?{|opt| opts[opt].nil? }
      raise "missing a required option (#{REQUIRED_OPTIONS}) missing: #{REQUIRED_OPTIONS.select{|opt| opts[opt].nil? }}"
    end
  end

  def project_key
    "#{user}/#{name}"
  end

  def commit_key
    "#{project_key}/#{commit}"
  end

  def repo_location
    "#{repos_dir}#{name}"
  end

  def create_or_update_repo
    if File.exists?(repo_location)
      #logger.info("update repo")
      `cd #{repo_location}; git pull`
    else
      #logger.info("create repo")
      `cd #{repos_dir}; git clone #{url}`
    end
  end
  
  def process_request(project_request)
    create_or_update_repo

    results = "error running systemu"
    Dir.chdir(repo_location) do
      
      cid = fork do
        ENV['REQUEST_METHOD']=nil
        ENV['REQUEST_URI']=nil
        ENV['QUERY_STRING']=nil
        ENV['PWD']=nil
        ENV['DOCUMENT_ROOT']=nil
        ENV['BUNDLE_GEMFILE']="#{repo_location}/Gemfile"
        full_cmd = "cd #{repo_location}; LC_ALL=en_US.UTF-8 LC_CTYPE=en_US.UTF-8 PORT=#{PAYLOAD_PORT} foreman start > /opt/bitnami/apps/server_responder/log/foreman.log"
        #logger.info "running: #{full_cmd}"
        exec(full_cmd)
      end

      puts "running child is #{cid}"
      begin
        #logger.info "sleep while app boots"
        sleep(7)
        #logger.info "waking up to hit app"
        results = RestClient.post "http://localhost:#{PAYLOAD_PORT}#{project_request}", {}
        #logger.error "results: #{results}"
        write_file(results_location,results)
      rescue => error
        error_msg = "error hitting app #{error}"
        #logger.error error_msg
        error_trace = "error trace #{error.backtrace.join("\n")}"
        #logger.error error_trace
        write_file(results_location, "#{error_msg}\n #{error_trace}")
      ensure
        begin
          #logger.info "killing child processes"
          Process.kill '-SIGINT', cid # kill the daemon
        rescue Errno::ESRCH
          #logger.error "error killing process likely crashed when running"
        end
      end
    end
    results
  end

  def process_cmd(cmd)
    create_or_update_repo
    if commit=='history'
      Project.project_history_for_command(project_key, repo_location, default_local_location, repo_url, commit, commit_key, cmd, results_location)
    else
      Project.project_command(project_key, repo_location, default_local_location, repo_url, commit, commit_key, cmd, results_location)
    end
  end

  def process_github_hook
    create_or_update_repo
    deferred_server_config = "#{repo_location}/.deferred_server"
    cmd = "churn"
    if File.exists?(deferred_server_config)
      cmd = File.read(deferred_server_config)
      results = nil
      Dir.chdir(repo_location) do
        if File.exists?("#{repo_location}/Gemfile")
          `chmod +w Gemfile.lock`
          `gem install bundler --no-ri --no-rdoc`
          `BUNDLE_GEMFILE=#{repo_location}/Gemfile && bundle install`
        end
        full_cmd = "BUNDLE_GEMFILE=#{repo_location}/Gemfile && #{cmd}"
        #logger.info "dir: #{repo_location} && running: #{full_cmd}"
        results = `#{full_cmd} 2>&1`
      end
    else
      results = `cd #{repo_location}; #{cmd}`
    end
    puts "results: #{results}"
    exit_status = $?.exitstatus
    json_results = {
      :cmd_run     => cmd,
      :exit_status => exit_status,
      :results     => results
    }
    write_file(commit_key,json_results.to_json)
    write_commits(project_key, commit, commit_key, push)
    RestClient.post CLIENT_APP+"/request_complete",
    {:project_key => project_key, :commit_key => commit_key}
    json_results
  end

  def self.project_history_for_command(project_key, repo_location, default_local_location, repo_url, commit, commit_key, cmd, results_location)
    from_date  = 60.days.ago.to_date
    until_date = Date.today
    completed_commits = []

    #from https://github.com/metricfu/metric_fu/issues/107#issuecomment-21747147
    (from_date..until_date).each do |date|
      git_log_cmd = "cd #{repo_location}; git log --max-count=1 --before=#{date} --after=#{date - 1} --format='%H'"
      puts "git_log_cmd: #{git_log_cmd}"
      current_git_commit = `#{git_log_cmd}`.to_s.strip
      puts "commit #{current_git_commit} for date #{date}"
      if current_git_commit!='' && !completed_commits.include?(current_git_commit)
        completed_commits << current_git_commit
        current_commit_key       = "#{project_key}/#{current_git_commit}"
        current_results_location = results_location.gsub('_history_',"_#{current_git_commit}_")
        
        project_command(project_key, repo_location, default_local_location, repo_url, current_git_commit, current_commit_key, cmd, current_results_location)
        RestClient.post("http://churn.picoappz.com/#{project_key}/commits/#{current_git_commit}", :rechurn => 'false')
      end
    end
    {:project_key => project_key, :commit_key => commit_key}
  end

  def self.project_command(project_key, repo_location, default_local_location, repo_url, commit, commit_key, cmd, results_location)
    if File.exists?(repo_location)
      puts ("update repo")
      `cd #{repo_location}; git pull`
    else
      puts("create repo")
      `cd #{local_repos}; git clone #{repo_url}`
    end

    full_command = "cd #{repo_location}; git checkout #{commit}; #{cmd}"
    puts ("running: #{full_command}")
    results = `#{full_command}`
    #temporary hack for the empty results not creating files / valid output
    if results==''
      results = "cmd #{cmd} completed with no output"
    end
    puts "results: #{results}"
    exit_status = $?.exitstatus
    json_results = {
      :cmd_run     => cmd,
      :exit_status => exit_status,
      :results     => results
    }
    write_file(commit_key,json_results.to_json)
    write_file(results_location,json_results.to_json)
    
    RestClient.post "http://git-hook-responder.herokuapp.com"+"/request_complete",
    {:project_key => project_key, :commit_key => commit_key}
    
    results
  end
  
end
