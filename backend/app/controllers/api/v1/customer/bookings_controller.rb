module Api
  module V1
    module Customer
      class BookingsController < BaseController
        include Idempotent

        idempotent :approvals

        # GET /api/v1/customer/bookings — newest first.
        def index
          authorize [ :customer, Booking ]
          records, meta = paginate(scope, order: { id: :desc })
          render_data(records.map { |b| CustomerBookingResource.new(b).to_h }, meta:)
        end

        # GET /api/v1/customer/bookings/:id
        def show
          render_booking(find_booking(:show?))
        end

        # POST /api/v1/customer/bookings/:id/approvals { revision_id, decision: approved|rejected } + Idempotency-Key
        # Approves or rejects the price waiting for the customer (final price after an inspection, or extra charges).
        def approvals
          booking = find_booking(:act?)
          decision = params.require(:decision)
          raise ApplicationError.new(:invalid_decision, status: :bad_request) unless %w[approved rejected].include?(decision)

          stage = booking.awaiting_final_approval? ? "final" : "change"
          event = "#{decision == 'approved' ? 'approve' : 'reject'}_#{stage}"
          Bookings::Perform.call(booking:, event:, actor: current_user, role: "customer", params: { revision_id: params.require(:revision_id) },
                                 ip: request.remote_ip, user_agent: request.user_agent)
          render_booking(booking)
        end

        # POST /api/v1/customer/bookings/:id/cancel { reason? } — before the work starts.
        def cancel
          booking = find_booking(:act?)
          Bookings::Perform.call(booking:, event: :cancel, actor: current_user, role: "customer", params: { reason: params[:reason] })
          render_booking(booking)
        end

        # GET /api/v1/customer/bookings/:id/messages
        def messages
          booking = find_booking(:message?)
          render_data(booking.messages.includes(:sender).map { |m| MessageResource.new(m).to_h })
        end

        # POST /api/v1/customer/bookings/:id/messages { body }
        def post_message
          booking = find_booking(:message?)
          message = Bookings::PostMessage.call(booking:, sender: current_user, role: "customer", body: params.require(:body))
          render_data(MessageResource.new(message).to_h, status: :created)
        end

        # POST /api/v1/customer/bookings/:id/review { rating: 1..5, body? }
        def review
          booking = find_booking(:review?)
          Reviews::Create.call(booking:, customer: current_user, rating: params.require(:rating), body: params[:body])
          render_booking(booking, status: :created)
        end

        # POST /api/v1/customer/bookings/:id/disputes { category, description }
        def disputes
          booking = find_booking(:dispute?)
          Disputes::Open.call(booking:, customer: current_user, category: params.require(:category), description: params.require(:description))
          render_booking(booking, status: :created)
        end

        private

        def scope
          policy_scope([ :customer, Booking ])
            .includes(:pending_revision, :status_histories, :review, :disputes, approvals: { quotation_revision: :items },
                      quotation: { revisions: :items }, service_request: %i[service_category city],
                      worker_profile: [ :user, { photo_attachment: :blob } ])
        end

        def find_booking(query)
          booking = scope.find_by!(public_id: params[:id])
          authorize [ :customer, booking ], query
          booking
        end

        def render_booking(booking, status: :ok)
          render_data(CustomerBookingResource.new(scope.find(booking.id)).to_h, status:)
        end
      end
    end
  end
end
