module RedmineWebhook
  class WebhookListener < Redmine::Hook::Listener

    def controller_issues_new_after_save(context = {})
      issue = context[:issue]
      controller = context[:controller]
      project = issue.project
      webhooks = Webhook.where(:project_id => project.project.id)
      return unless webhooks
      post(webhooks, issue_to_json(issue, controller))
    end

    def controller_issues_edit_after_save(context = {})
      journal = context[:journal]
      controller = context[:controller]
      issue = context[:issue]
      project = issue.project
      webhooks = Webhook.where(:project_id => project.project.id)
      return unless webhooks
      post(webhooks, journal_to_json(issue, journal, controller))
    end
    
    def controller_agile_boards_update_after_save(context = {})
      issue = context[:issue]
      project = issue.project
      webhooks = Webhook.where(:project_id => project.project.id)
      return unless webhooks
      post(webhooks, core_issue_to_json(issue))
    end
   

    private
    def issue_to_json(issue, controller)
      {
        :payload => {
          :action => 'opened',
          :issue => RedmineWebhook::IssueWrapper.new(issue).to_hash,
          :url => controller.issue_url(issue)
        }
      }.to_json
    end

    def journal_to_json(issue, journal, controller)
      {
        :payload => {
          :action => 'updated',
          :issue => RedmineWebhook::IssueWrapper.new(issue).to_hash,
          :journal => RedmineWebhook::JournalWrapper.new(journal).to_hash,
          :url => controller.issue_url(issue)
        }
      }.to_json
    end
    
    def core_issue_to_json(issue)
      {
        :payload => {
          :action => 'bulk_updated',
          :issue => RedmineWebhook::IssueWrapper.new(issue).to_hash
        }
      }.to_json
    end

    def post(webhooks, request_body)
      Thread.start do
        webhooks.each do |webhook|
          begin
            Faraday.post do |req|
              req.url webhook.url
              req.headers['Content-Type'] = 'application/json'
              req.body = request_body
            end
          rescue => e
            Rails.logger.error e
          end
        end
      end
    end
  end
end
