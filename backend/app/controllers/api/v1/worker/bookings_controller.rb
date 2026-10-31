module Api
  module V1
    module Worker
      class BookingsController < BaseController
        # GET /api/v1/worker/bookings — jobs won, newest first.
        def index
          authorize [ :worker, Booking ]
          records, meta = paginate(scope, order: { id: :desc })
          render_data(records.map { |b| WorkerBookingResource.new(b).to_h }, meta:)
        end

        # GET /api/v1/worker/bookings/:id — with the customer's contact and full address.
        def show
          booking = scope.find_by!(public_id: params[:id])
          authorize [ :worker, booking ]
          render_data(WorkerBookingResource.new(booking).to_h)
        end

        private

        def scope
          policy_scope([ :worker, Booking ])
            .includes(:customer, approvals: { quotation_revision: :items }, quotation: { revisions: :items },
                      service_request: [ :service_category, :city, { attachments: { file_attachment: :blob } } ])
        end
      end
    end
  end
end
