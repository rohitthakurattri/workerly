module Api
  module V1
    module Customer
      class QuotationsController < BaseController
        include Idempotent

        idempotent :accept

        # GET /api/v1/customer/service_requests/:service_request_id/quotations — cheapest first.
        def index
          authorize [ :customer, Quotation ]
          service_request = find_request
          quotes = scope.where(service_request:).to_a.sort_by { |q| [ q.accepted? ? 0 : 1, q.current_revision.total_minor, q.id ] }
          render_data(quotes.map { |q| QuotationResource.new(q).to_h })
        end

        # GET /api/v1/customer/quotations/:id — includes the price history.
        def show
          quotation = find_quotation
          authorize [ :customer, quotation ]
          render_data(QuotationResource.new(quotation).to_h.merge(
            revisions: quotation.revisions.map { |r| { version: r.version, total: Shared::Money.to_h(r.total_minor, r.currency_code), created_at: r.created_at.iso8601 } }
          ))
        end

        # POST /api/v1/customer/quotations/:id/accept { version } + Idempotency-Key header
        def accept
          quotation = find_quotation
          authorize [ :customer, quotation ]
          version = params.require(:version)
          booking = Quotations::Accept.call(quotation:, version:, customer: current_user, ip: request.remote_ip, user_agent: request.user_agent)
          render_data(CustomerBookingResource.new(booking.reload).to_h, status: :created)
        end

        # POST /api/v1/customer/quotations/:id/decline { reason? }
        def decline
          quotation = find_quotation
          authorize [ :customer, quotation ]
          Quotations::Decline.call(quotation:, reason: params[:reason])
          render_data(QuotationResource.new(quotation).to_h)
        end

        private

        def scope
          policy_scope([ :customer, Quotation ])
            .includes(:invitation, :booking, revisions: :items, worker_profile: [ :user, { photo_attachment: :blob } ])
        end

        def find_quotation = scope.find_by!(public_id: params[:id])
      end
    end
  end
end
