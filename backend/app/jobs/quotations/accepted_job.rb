module Quotations
  # After an accept commits: the winner hears first (SMS fallback: it's a critical event), the
  # others are told, and every invited worker's lead closes.
  class AcceptedJob < ApplicationJob
    queue_as :critical

    def perform(booking_id)
      booking = Booking.includes(:quotation, worker_profile: :user, service_request: :service_category).find(booking_id)
      request = booking.service_request
      winner = booking.worker_profile
      user = winner.user
      category = request.service_category.name(user.locale)
      locality = request.address_snapshot["locality"]

      WorkerLeadsChannel.broadcast_to(winner, { type: "quote.status", lead_id: request.public_id, id: booking.quotation.public_id,
                                                status: "accepted", booking_id: booking.public_id })
      Notifications::Deliver.call(
        user:, app: "worker", kind: "quote.accepted",
        title: I18n.t("notifications.quote_accepted.title", category:, locale: user.locale),
        body: I18n.t("notifications.quote_accepted.body", locality:, locale: user.locale),
        url: "/jobs/#{booking.public_id}", data: { booking_id: booking.public_id },
        sms: I18n.t("notifications.quote_accepted.sms", category:, locality:, locale: :en)
      )
      RequestChannel.broadcast_to(request, { type: "request.booked", booking_id: booking.public_id })

      request.quotations.where(status: "declined", decline_reason: "another_accepted").find_each do |q|
        Events.worker_status(q)
        QuotationDecidedJob.perform_later(q.id)
      end
      Matching::CloseLeads.call(request)
    end
  end
end
