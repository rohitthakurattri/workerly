module Workers
  # Tells the worker about a verification decision by SMS (registered templates, see
  # config/sms_templates.yml).
  class VerificationNotificationJob < ApplicationJob
    queue_as :default
    self.log_arguments = false

    TEMPLATES = { "approved" => :worker_approved, "changes_requested" => :worker_changes_requested, "rejected" => :worker_rejected }.freeze

    def perform(profile_id, decision)
      template = TEMPLATES[decision] or return
      profile = WorkerProfile.includes(:user).find(profile_id)
      Adapters::Sms.adapter.deliver(to: profile.user.phone_e164, message: Adapters::Sms.message(template))
    rescue Adapters::Sms::Error => e
      raise if e.retryable?

      Rails.logger.error("[VerificationNotification] SMS not sent: #{e.code} #{e.message}")
    end
  end
end
