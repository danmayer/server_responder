class ProjectCommands

  def self.project_history_for_command(project_key, repo_location, default_local_location, repo_url, commit, commit_key, cmd, results_location)
    from_date  = 30.days.ago.to_date
    until_date = Date.today

    #from https://github.com/metricfu/metric_fu/issues/107#issuecomment-21747147
    (from_date..until_date).each do |date|
      git_log_cmd = "cd #{repo_location}; git log --max-count=1 --before=#{date} --after=#{date - 1} --format='%H'"
      puts "git_log_cmd: #{git_log_cmd}"
      current_git_commit = `#{git_log_cmd}`.to_s.strip
      current_commit_key   = "#{project_key}/#{current_git_commit}"
      project_command(project_key, repo_location, default_local_location, repo_url, current_git_commit, current_commit_key, cmd, results_location)
      #resource = RestClient::Resource.new("http://churn.picoappz.com/#{project_key}/commits/#{current_git_commit}")
      #resource.post(:rechurn => 'false')
    end
    {:project_key => project_key, :commit_key => commit_key}
  end

  def self.project_command(project_key, repo_location, default_local_location, repo_url, commit, commit_key, cmd, results_location)
    if File.exists?(repo_location)
      logger.info("update repo")
      `cd #{repo_location}; git pull`
    else
      logger.info("create repo")
      `cd #{local_repos}; git clone #{repo_url}`
    end

    full_command = "cd #{repo_location}; git checkout #{commit}; #{cmd}"
    logger.info("running: #{full_command}")
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