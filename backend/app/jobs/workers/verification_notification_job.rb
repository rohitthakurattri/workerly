module Workers
  # Tells the worker about a verification decision by SMS. In-app and push
  # notifications replace most of this once the Notifications module lands (Phase 4).
  class VerificationNotificationJob < ApplicationJob
    queue_as :default
    self.log_arguments = false

    MESSAGES = {
      "approved" => "Your Workerly Pro profile is approved. You will now receive job requests near you.",
      "changes_requested" => "Your Workerly Pro profile needs a few changes. Open the app to see what to fix.",
      "rejected" => "Your Workerly Pro application was not approved. Open the app for details."
    }.freeze

    def perform(profile_id, decision)
      message = MESSAGES[decision] or return
      profile = WorkerProfile.includes(:user).find(profile_id)
      Adapters::Sms.adapter.deliver(to: profile.user.phone_e164, body: message)
    end
  end
end
