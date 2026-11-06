module Adapters
  module Payments
    # Behaves like Razorpay without the network: orders and refunds get ids, signatures use the
    # same HMAC scheme with local secrets, and Api::V1::Dev::FakePaymentsController plays the
    # gateway's part (it sends the signed webhook a real payment would).
    class Fake
      def name = "fake"
      def key_id = "rzp_test_fake"

      def create_order(amount_minor:, currency:, receipt:, notes: {})
        { id: "order_fake_#{SecureRandom.hex(8)}", amount: amount_minor, currency:, receipt:, notes: }
      end

      def refund(provider_payment_id:, amount_minor:, notes: {})
        { id: "rfnd_fake_#{SecureRandom.hex(8)}", payment_id: provider_payment_id, amount: amount_minor, status: "processed", notes: }
      end

      # The fake gateway reports through its signed webhook (dev route), so there's nothing to pull.
      def order_payments(_order_id) = []
      def fetch_refund(refund_id) = { id: refund_id, status: "processed" }
      def test_mode? = true

      def checkout_signature_valid?(order_id:, payment_id:, signature:)
        Payments.secure_compare(Payments.hmac(Workerly.config.razorpay_key_secret, "#{order_id}|#{payment_id}"), signature)
      end

      def webhook_signature_valid?(body:, signature:)
        Payments.secure_compare(Payments.hmac(Workerly.config.razorpay_webhook_secret, body), signature)
      end
    end
  end
end
