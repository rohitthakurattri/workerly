module Api
  module V1
    module Customer
      class PaymentsController < BaseController
        include Idempotent

        idempotent :create

        # POST /api/v1/customer/bookings/:booking_id/payments + Idempotency-Key
        # Starts an online payment for what's owed; returns what the checkout needs.
        def create
          booking = policy_scope([ :customer, Booking ]).find_by!(public_id: params[:booking_id])
          authorize [ :customer, booking ], :act?
          payment = Payments::CreateOrder.call(booking:, idempotency_key: request.headers["Idempotency-Key"])
          adapter = Adapters::Payments.adapter
          render_data({
            payment: PaymentResource.new(payment).to_h,
            checkout: { provider: adapter.name, key_id: adapter.key_id, order_id: payment.provider_order_id,
                        amount: payment.amount_minor, currency: payment.currency_code, name: "Workerly",
                        description: booking.service_request.service_category.name, prefill: { contact: current_user.phone_e164 } }
          }, status: :created)
        end

        # GET /api/v1/customer/payments/:id — the app polls this after checkout until the webhook lands.
        # While an order is being paid, it also asks the gateway (at most every few seconds), so a
        # slow or missing webhook (always the case on localhost) doesn't leave the customer waiting.
        def show
          payment = find_payment
          authorize [ :customer, payment ]
          sync(payment) if payment.created? && payment.created_at > Payments::Sync::FAIL_AFTER.ago && sync_due?(payment)
          render_data(PaymentResource.new(payment.reload).to_h)
        end

        # POST /api/v1/customer/payments/:id/verify { razorpay_payment_id, razorpay_order_id, razorpay_signature }
        # The checkout's callback. Its signature only proves the browser saw a payment; it never marks
        # anything paid. What does: the signed webhook, or the gateway's own answer when we ask it.
        def verify
          payment = find_payment
          authorize [ :customer, payment ]
          valid = params[:razorpay_order_id] == payment.provider_order_id &&
                  Adapters::Payments.adapter.checkout_signature_valid?(order_id: payment.provider_order_id, payment_id: params[:razorpay_payment_id].to_s,
                                                                       signature: params[:razorpay_signature].to_s)
          raise ApplicationError.new(:invalid_signature, status: :bad_request) unless valid

          sync(payment)
          render_data(PaymentResource.new(payment.reload).to_h)
        end

        private

        def find_payment = policy_scope([ :customer, Payment ]).find_by!(public_id: params[:id])

        # Best effort: if the gateway can't be reached, the webhook or SyncPendingJob settles it later.
        def sync(payment)
          Payments::Sync.call(payment)
        rescue Adapters::Payments::Error => e
          Rails.logger.warn("[Payments] sync #{payment.public_id}: #{e.code}")
        end

        SYNC_EVERY = 3.seconds

        def sync_due?(payment) = Rails.cache.write("payment-sync:#{payment.id}", 1, expires_in: SYNC_EVERY, unless_exist: true)
      end
    end
  end
end
