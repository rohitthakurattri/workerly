module Bookings
  # A booking ended before the work started (cancelled, or the customer said no to the price
  # after an inspection). If the request hasn't expired, it takes quotes again: the other quotes
  # that lost to this one come back, if still valid and their workers can still take jobs.
  # Called inside Bookings::Perform's transaction with the request locked.
  module ReopenRequest
    module_function

    def call(booking, now: Time.current)
      request = booking.service_request
      booking.quotation.update!(status: "declined", declined_at: now, decline_reason: "booking_cancelled")
      if request.expires_at <= now
        request.update!(status: "expired")
        return false
      end

      restorable = request.quotations.where(status: "declined", decline_reason: "another_accepted").where("valid_until > ?", now)
                          .includes(worker_profile: :user).select { |q| q.worker_profile.can_receive_leads? }
      Quotation.where(id: restorable.map(&:id)).update_all(status: "submitted", declined_at: nil, decline_reason: nil, updated_at: now)
      request.update!(status: restorable.any? ? "quoting" : "open")
      true
    end
  end
end
