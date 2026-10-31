module Reviews
  # One review per finished booking, by its customer, within REVIEW_WINDOW_DAYS of completion.
  # The worker's average feeds matching (Matching::Rank's Bayesian rating).
  module Create
    module_function

    def call(booking:, customer:, rating:, body: nil, now: Time.current)
      raise ApplicationError.new(:review_not_allowed, status: :conflict, details: { status: booking.status }) unless booking.done?
      if booking.completed_at < now - Workerly.config.review_window_days.days
        raise ApplicationError.new(:review_window_closed, status: :conflict)
      end

      profile = booking.worker_profile
      review = WorkerProfile.transaction do
        profile.lock!
        Review.create!(booking:, reviewer: customer, worker_profile: profile, rating: rating.to_i, body: body.to_s.strip.presence).tap do
          profile.update!(rating_count: profile.reviews.count, rating_avg: profile.reviews.average(:rating).round(2))
        end
      end
      BookingChannel.broadcast_to(booking, { type: "booking.updated", id: booking.public_id, status: booking.status, event: "review" })
      review
    rescue ActiveRecord::RecordNotUnique
      raise ApplicationError.new(:already_reviewed, status: :conflict)
    end
  end
end
