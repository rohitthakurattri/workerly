module Api
  module V1
    module Worker
      class BookingsController < BaseController
        REVISION_PARAMS = [ :notes, :estimated_minutes,
                            { items: %i[type description brand quantity unit unit_price_minor condition warranty_days] } ].freeze

        # GET /api/v1/worker/bookings — jobs won, newest first.
        def index
          authorize [ :worker, Booking ]
          records, meta = paginate(scope, order: { id: :desc })
          render_data(records.map { |b| WorkerBookingResource.new(b).to_h }, meta:)
        end

        # GET /api/v1/worker/bookings/:id — with the customer's contact and full address.
        def show
          render_booking(find_booking(:show?))
        end

        # POST /api/v1/worker/bookings/:id/schedule { scheduled_at } — also reschedules.
        def schedule = perform(:schedule, scheduled_at: params.require(:scheduled_at))

        # POST /api/v1/worker/bookings/:id/check_in — arrived for the inspection.
        def check_in = perform(:check_in)

        # POST /api/v1/worker/bookings/:id/final_quotation { items, notes?, estimated_minutes? }
        def final_quotation = perform(:final_quotation, **revision_params)

        # POST /api/v1/worker/bookings/:id/start
        def start = perform(:start)

        # POST /api/v1/worker/bookings/:id/change_orders { items, notes? } — extra charges, needs the customer's approval.
        def change_orders = perform(:change_order, **revision_params)

        # POST /api/v1/worker/bookings/:id/complete
        def complete = perform(:complete)

        # POST /api/v1/worker/bookings/:id/cancel { reason? } — before the work starts.
        def cancel = perform(:cancel, reason: params[:reason])

        # GET /api/v1/worker/bookings/:id/messages
        def messages
          booking = find_booking(:message?)
          render_data(booking.messages.includes(:sender).map { |m| MessageResource.new(m).to_h })
        end

        # POST /api/v1/worker/bookings/:id/messages { body }
        def post_message
          booking = find_booking(:message?)
          message = Bookings::PostMessage.call(booking:, sender: current_user, role: "worker", body: params.require(:body))
          render_data(MessageResource.new(message).to_h, status: :created)
        end

        private

        def perform(event, **event_params)
          booking = find_booking(:act?)
          Bookings::Perform.call(booking:, event:, actor: current_user, role: "worker", params: event_params)
          render_booking(booking)
        end

        def revision_params = params.permit(*REVISION_PARAMS).to_h.symbolize_keys

        def scope
          policy_scope([ :worker, Booking ])
            .includes(:customer, :pending_revision, :status_histories, :review, :disputes,
                      approvals: { quotation_revision: :items }, quotation: { revisions: :items },
                      service_request: [ :service_category, :city, { attachments: { file_attachment: :blob } } ])
        end

        def find_booking(query)
          booking = scope.find_by!(public_id: params[:id])
          authorize [ :worker, booking ], query
          booking
        end

        def render_booking(booking)
          render_data(WorkerBookingResource.new(scope.find(booking.id)).to_h)
        end
      end
    end
  end
end
