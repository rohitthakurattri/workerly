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

      def checkout_signature_valid?(order_id:, payment_id:, signature:)
        Payments.secure_compare(Payments.hmac(Workerly.config.razorpay_key_secret, "#{order_id}|#{payment_id}"), signature)
      end

      def webhook_signature_valid?(body:, signature:)
        Payments.secure_compare(Payments.hmac(Workerly.config.razorpay_webhook_secret, body), signature)
      end

      private

      def post(path, body)
        raise Error.new(:not_configured, "RAZORPAY_KEY_ID and RAZORPAY_KEY_SECRET are required") if key_id.blank? || Workerly.config.razorpay_key_secret.blank?

        uri = API + path
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        http.open_timeout = 3
        http.read_timeout = 10
        req = Net::HTTP::Post.new(uri, "Content-Type" => "application/json")
        req.basic_auth(key_id, Workerly.config.razorpay_key_secret)
        req.body = body.to_json
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
