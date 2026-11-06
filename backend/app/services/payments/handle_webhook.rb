module Payments
  # One Razorpay webhook delivery. The signature is checked against the raw body, the event is
  # stored once (unique provider + event id) and applied in the same transaction, so a
  # redelivery or a concurrent duplicate changes nothing. If applying fails, nothing is stored
  # and we answer 500 so Razorpay retries.
  module HandleWebhook
    module_function

    Result = Data.define(:status, :event)

    def call(body:, signature:, event_id:, provider: "razorpay", now: Time.current)
      adapter = Adapters::Payments.adapter
      return Result.new(status: :invalid_signature, event: nil) unless adapter.webhook_signature_valid?(body:, signature:)

      data = JSON.parse(body)
      event_id = event_id.presence || Digest::SHA256.hexdigest(body) # Razorpay always sends x-razorpay-event-id
      event = PaymentEvent.transaction(requires_new: true) do
        PaymentEvent.create!(provider:, provider_event_id: event_id, event_type: data["event"].to_s, payload: data,
                             signature_valid: true, processed_at: now).tap { apply(data, now:) }
      end
      Result.new(status: :processed, event:)
    rescue ActiveRecord::RecordNotUnique
      Result.new(status: :duplicate, event: nil)
    rescue JSON::ParserError
      Result.new(status: :invalid_payload, event: nil)
    end

    def apply(data, now:)
      payment_entity = data.dig("payload", "payment", "entity") || {}
      refund_entity = data.dig("payload", "refund", "entity") || {}
      case data["event"]
      when "payment.captured", "order.paid"
        payment = Payment.find_by(provider_order_id: payment_entity["order_id"])
        return unless payment

        Capture.call(payment:, provider_payment_id: payment_entity["id"], amount_minor: payment_entity["amount"],
                     currency: payment_entity["currency"], now:)
      when "payment.failed"
        payment = Payment.find_by(provider_order_id: payment_entity["order_id"])
        payment&.with_lock do
          payment.update!(status: "failed", failed_at: now, failure_reason: payment_entity["error_description"].to_s.first(255)) if payment.created?
        end
      when "refund.processed"
        refund = Refund.find_by(provider_refund_id: refund_entity["id"])
        Refunds::Complete.call(refund:, now:) if refund
      when "refund.failed"
        refund = Refund.find_by(provider_refund_id: refund_entity["id"])
        refund&.with_lock { refund.update!(status: "failed") if refund.status == "pending" }
      end
    end
  end
end
