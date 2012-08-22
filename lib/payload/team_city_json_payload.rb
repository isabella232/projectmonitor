class TeamCityJsonPayload < Payload

  def building?
    status_content.first['buildResult'] == 'running' && status_content.first['notifyType'] == 'buildStarted'
  end

  def convert_content!(content)
    [JSON.parse(content)["build"]]
  rescue => e
    log_error(e)
    self.processable = self.build_processable = false
    []
  end

  def parse_success(content)
    return if content['buildResult'] == 'running'
    content['buildResult'] == 'success'
  end

  def parse_url(content)
    self.parsed_url = "http://#{remote_addr}:8111/viewType.html?buildTypeId=#{parse_build_type_id(content)}"
    "http://#{remote_addr}:8111/viewLog.html?buildId=#{parse_build_id(content)}&tab=buildResultsDiv&buildTypeId=#{parse_build_type_id(content)}"
  end

  def parse_build_type_id(content)
    content['buildTypeId']
  end

  def parse_build_id(content)
    content['buildId']
  end

  def parse_published_at(content)
    Time.now
  end

end
