class ProjectCommands

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
