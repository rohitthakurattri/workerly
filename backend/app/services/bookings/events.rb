module Bookings
  # After a booking event commits: both parties' open screens refresh, and the other party is told.
  module Events
    module_function

    def changed(booking, event, from:, role:, reopened: false)
      BookingChannel.broadcast_to(booking, { type: "booking.updated", id: booking.public_id, status: booking.status, event: event.to_s })
      NotifyJob.perform_later(booking.id, event.to_s, role)
      RequestReopenedJob.perform_later(booking.service_request_id, booking.worker_profile_id) if reopened
      return unless from != booking.status && %w[cancelled closed_after_inspection completed].include?(booking.status)

      # The request page shows the booking state too.
      RequestChannel.broadcast_to(booking.service_request, { type: "request.updated", booking_id: booking.public_id })
    end
  end
end
