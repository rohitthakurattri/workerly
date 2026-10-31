module Api
  module V1
    module Customer
      class BookingsController < BaseController
        # GET /api/v1/customer/bookings — newest first.
        def index
          authorize [ :customer, Booking ]
          records, meta = paginate(scope, order: { id: :desc })
          render_data(records.map { |b| CustomerBookingResource.new(b).to_h }, meta:)
        end

        # GET /api/v1/customer/bookings/:id
        def show
          booking = scope.find_by!(public_id: params[:id])
          authorize [ :customer, booking ]
          render_data(CustomerBookingResource.new(booking).to_h)
        end

        private

        def scope
          policy_scope([ :customer, Booking ])
            .includes(approvals: { quotation_revision: :items }, quotation: { revisions: :items },
                      service_request: %i[service_category city], worker_profile: [ :user, { photo_attachment: :blob } ])
        end
      end
    end
  end
end
