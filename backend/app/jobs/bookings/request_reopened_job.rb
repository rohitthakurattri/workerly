module Bookings
  # The booking ended before work started and the request takes quotes again: invited workers'
  # open apps get the lead back, and workers whose quotes were restored are told.
  class RequestReopenedJob < ApplicationJob
    queue_as :default

    def perform(request_id, previous_worker_id)
      request = ServiceRequest.find(request_id)
      return unless ServiceRequest::QUOTABLE_STATUSES.include?(request.status)

      RequestChannel.broadcast_to(request, { type: "request.reopened" })
      request.invitations.where(declined_at: nil).where.not(worker_profile_id: previous_worker_id)
             .includes(:quotation, worker_profile: :user, service_request: %i[service_category city]).find_each do |inv|
        next unless inv.worker_profile.can_receive_leads?

        WorkerLeadsChannel.broadcast_to(inv.worker_profile, { type: "lead.new", lead: LeadResource.new(inv).to_h })
        next unless inv.quotation&.submitted?

        user = inv.worker_profile.user
        Notifications::Deliver.call(
          user:, app: "worker", kind: "quote.reopened", url: "/leads/#{request.public_id}", data: { lead_id: request.public_id },
          title: I18n.t("notifications.quote_reopened.title", category: request.service_category.name(user.locale), locale: user.locale)
        )
      end
    end
  end
end
