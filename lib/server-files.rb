module ServerFiles

  # TODO how to allow a server to write files without exposing the shared secrets...
  # Thinking a write ONLY ec2 key PER server
  def connection
    @connection ||= Fog::Storage.new(
                                  :provider          => 'AWS',
                                  :aws_access_key_id => ENV['AMAZON_ACCESS_KEY_ID'],
                                  :aws_secret_access_key => ENV['AMAZON_SECRET_ACCESS_KEY'])
  end

  def get_file(filename)
    begin
      file = directory.files.get(filename)
      file.body
    rescue
      ''
    end
  end
  
  def write_commits(project_key, after_commit, commit_key, push)
    commits_data = get_file(project_key)
    @commits = JSON.parse(commits_data) rescue {}
    @commits[after_commit] = {:uri => commit_key, :push => push }
    write_file(project_key, @commits.to_json)
  end

  def write_file(filename, body, options = {})
    file_options = {
      :key    => filename,
      :body   => body,
      :public => true
    }
    if options[:content_type]
      file_options[:content_type] = options[:content_type]
    end
    file = directory.files.new(file_options)
    file.save
  end

  def directory
    directory = connection.directories.create(
                                              :key    => "deferred-server",
                                              :public => true
                                              )
  end

end
