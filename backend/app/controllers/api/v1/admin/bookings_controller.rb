module Api
  module V1
    module Admin
      class BookingsController < BaseController
        UNSCHEDULED_AFTER = 24.hours
        LATE_AFTER = 2.hours
        APPROVAL_WAITING_AFTER = 24.hours

        # GET /api/v1/admin/bookings?filter[status]=…&filter[attention]=true&cursor=…
        # attention: not scheduled 24 h after booking, visit time passed 2 h ago without the
        # worker arriving, a price waiting 24 h for the customer, or a dispute.
        def index
          authorize [ :admin, Booking ]
          scope = base_scope
          status = params.dig(:filter, :status)
          if status.present?
            raise ApplicationError.new(:invalid_filter, status: :bad_request, details: { allowed: Booking::STATUSES }) unless Booking::STATUSES.include?(status)

            scope = scope.where(status:)
          end
          scope = needing_attention(scope) if params.dig(:filter, :attention) == "true"
          records, meta = paginate(scope, order: { id: :desc })
          render_data(records.map { |b| ::Admin::BookingSummaryResource.new(b).to_h },
                      meta: meta.merge(attention_count: needing_attention(policy_scope([ :admin, Booking ])).count))
        end

        # GET /api/v1/admin/bookings/:id
        def show
          booking = find_booking
          authorize [ :admin, booking ]
          render_data(::Admin::BookingResource.new(booking).to_h)
        end

        # POST /api/v1/admin/bookings/:id/cancel { reason } — audited.
        def cancel
          booking = find_booking
          authorize [ :admin, booking ]
          Bookings::Perform.call(booking:, event: :admin_cancel, actor: current_user, role: current_role, params: { reason: params[:reason] })
          render_data(::Admin::BookingResource.new(find_booking).to_h)
        end

        private

        def base_scope
          policy_scope([ :admin, Booking ]).includes(:customer, worker_profile: :user, service_request: :service_category)
        end

        def find_booking
          policy_scope([ :admin, Booking ])
            .includes(:customer, :pending_revision, :status_histories, :review, :disputes, { messages: :sender },
                      approvals: { quotation_revision: :items }, quotation: { revisions: :items },
                      worker_profile: :user, service_request: %i[service_category city])
            .find_by!(public_id: params[:id])
        end

        def needing_attention(scope)
          now = Time.current
          scope.where(status: "confirmed", confirmed_at: ...(now - UNSCHEDULED_AFTER))
               .or(scope.where(status: %w[scheduled inspection_scheduled], scheduled_at: ...(now - LATE_AFTER), started_at: nil, checked_in_at: nil))
               .or(scope.where(status: %w[awaiting_final_approval awaiting_change_approval], updated_at: ...(now - APPROVAL_WAITING_AFTER)))
               .or(scope.where(status: "disputed"))
        end
      end
    end
  end
end
