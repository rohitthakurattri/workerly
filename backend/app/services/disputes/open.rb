module Disputes
  # The customer reports a problem with finished work, within DISPUTE_WINDOW_DAYS. The booking
  # moves to `disputed` until support resolves it.
  module Open
    module_function

    def call(booking:, customer:, category:, description:, now: Time.current)
      unless booking.completed_at && booking.completed_at >= now - Workerly.config.dispute_window_days.days
        raise ApplicationError.new(:dispute_window_closed, status: :conflict)
      end

      dispute = nil
      Bookings::Perform.call(booking:, event: :dispute, actor: customer, role: "customer", now:) do
        dispute = booking.disputes.create!(raised_by: customer, category: category.to_s, description: description.to_s.strip)
      end
      dispute
    rescue ActiveRecord::RecordNotUnique
      raise ApplicationError.new(:dispute_already_open, status: :conflict)
    end
  end
end
