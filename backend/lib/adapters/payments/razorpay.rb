require "net/http"

module Adapters
  module Payments
    # Razorpay Orders + Refunds (https://razorpay.com/docs/api/). Amounts are in paise.
    # Checkout runs in the customer's browser with checkout.js; capture is confirmed only by the
    # signed `payment.captured` webhook (the browser callback is never trusted to mark a payment paid).
    class Razorpay
      API = URI("https://api.razorpay.com/v1/")

      def name = "razorpay"
      def key_id = Workerly.config.razorpay_key_id

      def create_order(amount_minor:, currency:, receipt:, notes: {})
        post("orders", { amount: amount_minor, currency:, receipt:, notes:, payment_capture: 1 })
      end

      def refund(provider_payment_id:, amount_minor:, notes: {})
        post("payments/#{provider_payment_id}/refund", { amount: amount_minor, speed: "normal", notes: })
      end

      # The payment attempts on an order (GET /orders/:id/payments): what the webhook would tell us,
      # asked directly with our secret. Statuses: created, authorized, captured, refunded, failed.
      def order_payments(order_id)
        get("orders/#{order_id}/payments").fetch(:items, [])
      end

      # GET /refunds/:id; status: pending, processed or failed.
      def fetch_refund(refund_id) = get("refunds/#{refund_id}")

      def test_mode? = key_id.to_s.start_with?("rzp_test_")

      def checkout_signature_valid?(order_id:, payment_id:, signature:)
        Payments.secure_compare(Payments.hmac(Workerly.config.razorpay_key_secret, "#{order_id}|#{payment_id}"), signature)
      end

      def webhook_signature_valid?(body:, signature:)
        Payments.secure_compare(Payments.hmac(Workerly.config.razorpay_webhook_secret, body), signature)
      end

      private

      def post(path, body)
        req = Net::HTTP::Post.new(API + path, "Content-Type" => "application/json")
        req.body = body.to_json
        request(req)
      end

      def get(path) = request(Net::HTTP::Get.new(API + path))

      def request(req)
        raise Error.new(:not_configured, "RAZORPAY_KEY_ID and RAZORPAY_KEY_SECRET are required") if key_id.blank? || Workerly.config.razorpay_key_secret.blank?

        http = Net::HTTP.new(req.uri.host, req.uri.port)
        http.use_ssl = true
        http.open_timeout = 3
        http.read_timeout = 10
        req.basic_auth(key_id, Workerly.config.razorpay_key_secret)
        res = http.request(req)
        data = JSON.parse(res.body.presence || "{}")
        raise Error.new(:gateway_error, data.dig("error", "description") || "HTTP #{res.code}") unless res.is_a?(Net::HTTPSuccess)

        data.deep_symbolize_keys
      rescue Net::OpenTimeout, Net::ReadTimeout, SocketError, Errno::ECONNREFUSED => e
        raise Error.new(:gateway_unavailable, e.message)
      end
    end
  end
end
