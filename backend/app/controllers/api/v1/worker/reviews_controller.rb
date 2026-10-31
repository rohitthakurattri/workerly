module Api
  module V1
    module Worker
      class ReviewsController < BaseController
        # GET /api/v1/worker/reviews — what customers said, newest first.
        def index
          authorize [ :worker, Review ]
          records, meta = paginate(current_profile.reviews.includes(:reviewer, booking: { service_request: :service_category }), order: { id: :desc })
          render_data(records.map do |r|
            { rating: r.rating, body: r.body, customer_name: r.reviewer.name&.split&.first,
              category: r.booking.service_request.service_category.name, created_at: r.created_at.iso8601 }
          end, meta: meta.merge(rating_avg: current_profile.rating_avg&.to_f, rating_count: current_profile.rating_count))
        end
      end
    end
  end
end
