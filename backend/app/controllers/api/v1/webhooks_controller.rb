module Api
  module V1
    # POST /api/v1/webhooks/razorpay — no session; authenticated by the HMAC signature of the raw body.
    class WebhooksController < BaseController
      skip_before_action :authenticate!

      def razorpay
        result = Payments::HandleWebhook.call(body: request.raw_post, signature: request.headers["X-Razorpay-Signature"].to_s,
                                              event_id: request.headers["X-Razorpay-Event-Id"].to_s)
        case result.status
        when :processed, :duplicate then render json: { status: result.status }, status: :ok
        when :invalid_signature then render_error(:unauthorized, :invalid_signature)
        else render_error(:bad_request, :invalid_payload)
        end
      end
    end
  end
end
