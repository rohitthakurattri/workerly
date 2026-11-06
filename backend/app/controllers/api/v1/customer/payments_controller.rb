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
        def show
          payment = find_payment
          authorize [ :customer, payment ]
          render_data(PaymentResource.new(payment).to_h)
        end

        # POST /api/v1/customer/payments/:id/verify { razorpay_payment_id, razorpay_order_id, razorpay_signature }
        # The checkout's callback. Checks the signature and remembers the gateway payment id, but
        # never marks anything paid: only the signed payment.captured webhook does that.
        def verify
          payment = find_payment
          authorize [ :customer, payment ]
          valid = params[:razorpay_order_id] == payment.provider_order_id &&
                  Adapters::Payments.adapter.checkout_signature_valid?(order_id: payment.provider_order_id, payment_id: params[:razorpay_payment_id].to_s,
                                                                       signature: params[:razorpay_signature].to_s)
          raise ApplicationError.new(:invalid_signature, status: :bad_request) unless valid

          render_data(PaymentResource.new(payment.reload).to_h)
        end

        private

        def find_payment = policy_scope([ :customer, Payment ]).find_by!(public_id: params[:id])
      end
    end
  end
end
