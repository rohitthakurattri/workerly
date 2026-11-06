module Api
  module V1
    module Admin
      class PaymentsController < BaseController
        include Idempotent

        idempotent :refund

        # GET /api/v1/admin/payments?filter[status]=…&filter[method]=online|cash
        def index
          authorize [ :admin, Payment ]
          scope = policy_scope([ :admin, Payment ]).includes(booking: [ :customer, { worker_profile: :user } ])
          { status: Payment::STATUSES, method: Payment::METHODS }.each do |key, allowed|
            value = params.dig(:filter, key)
            next if value.blank?
            raise ApplicationError.new(:invalid_filter, status: :bad_request, details: { allowed: }) unless allowed.include?(value)

            scope = scope.where(key => value)
          end
          records, meta = paginate(scope, order: { id: :desc })
          render_data(records.map { |p| serialize(p) }, meta:)
        end

        # POST /api/v1/admin/payments/:id/refunds { amount_minor, reason } + Idempotency-Key (finance, admin)
        def refund
          payment = policy_scope([ :admin, Payment ]).find_by!(public_id: params[:id])
          authorize [ :admin, payment ], :refund?
          Refunds::Create.call(payment:, amount_minor: params.require(:amount_minor), reason: params[:reason], auth: current_auth)
          render_data(serialize(payment.reload), status: :created)
        end

        private

        def serialize(p)
          PaymentResource.new(p).to_h.merge(
            booking_id: p.booking.public_id, customer_name: p.booking.customer.name, worker_name: p.booking.worker_profile.user.name,
            commission: p.commission_minor && Shared::Money.to_h(p.commission_minor, p.currency_code),
            worker_share: p.worker_share_minor && Shared::Money.to_h(p.worker_share_minor, p.currency_code),
            refundable: Shared::Money.to_h(p.refundable_minor, p.currency_code),
            refunds: p.refunds.map { |r| { id: r.public_id, amount: Shared::Money.to_h(r.amount_minor, p.currency_code), status: r.status, reason: r.reason } }
          )
        end
      end
    end
  end
end
