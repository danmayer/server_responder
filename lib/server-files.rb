module ServerFiles

  # TODO abstract out this class/module
  # this file is in both deferred-server and server-responder projects

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

  def get_projects
    projects_data = get_file('projects_json')
    @projects = JSON.parse(projects_data) rescue {}
  end

  def get_commits(project_key)
    commits_data = get_file(project_key)
    @commits = JSON.parse(commits_data) rescue {}
  end

  def write_commits(project_key, after_commit, commit_key)
    commits_data = get_file(project_key)
    @commits = JSON.parse(commits_data) rescue {}
    @commits[after_commit] = commit_key
    write_file(project_keym @commits.to_json)
  end

  def write_file(filename, body)
    file = directory.files.new({
                                 :key    => filename,
                                 :body   => body,
                                 :public => true
                               })
    file.save
  end

  def directory
    directory = connection.directories.create(
                                              :key    => "deferred-server",
                                              :public => true
                                              )
  end

end
