module Api
  module V1
    module Dev
      # Development and test only (routes are not drawn in production): plays Razorpay's part for
      # the fake adapter by sending the signed webhook a real capture or failure would send.
      class FakePaymentsController < BaseController
        skip_before_action :authenticate!

        # POST /api/v1/dev/fake_payments/:order_id/capture { fail? }
        def capture
          payment = Payment.find_by!(provider_order_id: params[:order_id], provider: "fake")
          provider_payment_id = "pay_fake_#{SecureRandom.hex(8)}"
          event = params[:fail] ? "payment.failed" : "payment.captured"
          body = { event:, payload: { payment: { entity: { id: provider_payment_id, order_id: payment.provider_order_id,
                                                           amount: payment.amount_minor, currency: payment.currency_code,
                                                           status: params[:fail] ? "failed" : "captured" } } } }.to_json
          Payments::HandleWebhook.call(body:, signature: Adapters::Payments.hmac(Workerly.config.razorpay_webhook_secret, body),
                                       event_id: "evt_fake_#{SecureRandom.hex(8)}")
          signature = Adapters::Payments.hmac(Workerly.config.razorpay_key_secret, "#{payment.provider_order_id}|#{provider_payment_id}")
          render_data({ razorpay_payment_id: provider_payment_id, razorpay_order_id: payment.provider_order_id, razorpay_signature: signature })
        end
      end
    end
  end
end
