module ProjectUpdater

  class << self

    def update(project)
      payload = project.fetch_payload

      begin
        fetch_status(project, payload)
        fetch_building_status(project, payload) unless project.feed_url == project.build_status_url

        log = PayloadProcessor.new(project, payload).process
        log.method = "Polling"
        log.save!

        log
      rescue => e
        project.online = false
        project.building = false
        backtrace = "#{e.message}\n#{e.backtrace.join("\n")}"
        project.payload_log_entries.build(error_type: e.class.to_s, error_text: e.message, method: "Polling", status: "failed", backtrace: backtrace)
      end
    end

  private

    def fetch_status(project, payload)
      retriever = UrlRetriever.new(project.feed_url, project.auth_username, project.auth_password, project.verify_ssl)
      payload.status_content = retriever.retrieve_content
    end

    def fetch_building_status(project, payload)
      retriever = UrlRetriever.new(project.build_status_url, project.auth_username, project.auth_password, project.verify_ssl)
      payload.build_status_content = retriever.retrieve_content
    end

  end

end
