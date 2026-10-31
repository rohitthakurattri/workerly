module Matching
  # Shows the lead live in the worker's open app, then push (or SMS) for when the app is closed.
  class NotifyWorkerJob < ApplicationJob
    queue_as :critical
    self.log_arguments = false

    def perform(invitation_id)
      inv = RequestInvitation.includes(:worker_profile, service_request: :service_category).find(invitation_id)
      return if inv.notified_at || inv.declined?

      request = inv.service_request
      profile = inv.worker_profile
      unless ServiceRequest::QUOTABLE_STATUSES.include?(request.status) && profile.can_receive_leads?
        return inv.update!(notified_at: Time.current, notified_via: "none")
      end

      WorkerLeadsChannel.broadcast_to(profile, { type: "lead.new", lead: LeadResource.new(inv).to_h })
      category = request.service_category.name(profile.user.locale)
      locality = request.address_snapshot["locality"]
      n = Notifications::Deliver.call(
        user: profile.user, app: "worker", kind: "lead.new",
        title: I18n.t("notifications.lead_new.title", category:, locale: profile.user.locale),
        body: I18n.t("notifications.lead_new.body", locality:, locale: profile.user.locale),
        url: "/leads/#{request.public_id}", data: { lead_id: request.public_id },
        sms: Workerly.config.lead_sms_fallback ? I18n.t("notifications.lead_new.sms", category:, locality:, locale: :en) : nil
      )
      inv.update!(notified_at: Time.current, notified_via: (n.channels & %w[push sms]).first || "none")
    end
  end
end
