module PaymentHelpers
  # A finished fixed-price job, through the real lifecycle.
  def completed_booking!(amount_minor: 95_000, **opts)
    booked!(amount_minor:, **opts).tap do |b|
      act!(b, :schedule, params: { scheduled_at: soon })
      act!(b, :start)
      act!(b, :complete)
      b.reload
    end
  end

  # A signed Razorpay-style webhook body for this payment.
  def webhook_body(payment, event: "payment.captured", amount: payment.amount_minor, currency: payment.currency_code, provider_payment_id: nil)
    { event:, payload: { payment: { entity: { id: provider_payment_id || "pay_#{payment.public_id.delete('-').first(14)}",
                                              order_id: payment.provider_order_id, amount:, currency:, status: "captured" } } } }.to_json
  end

  def sign_webhook(body) = Adapters::Payments.hmac(Workerly.config.razorpay_webhook_secret, body)

  def deliver_webhook(body, event_id: "evt_#{SecureRandom.hex(6)}")
    Payments::HandleWebhook.call(body:, signature: sign_webhook(body), event_id:)
  end

  def pay_online!(booking)
    payment = Payments::CreateOrder.call(booking:, idempotency_key: SecureRandom.uuid)
    deliver_webhook(webhook_body(payment))
    payment.reload
  end
end

RSpec.configure { |c| c.include PaymentHelpers }
