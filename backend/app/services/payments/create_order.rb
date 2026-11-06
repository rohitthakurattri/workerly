module Payments
  # The customer starts paying online what they owe. Creates our payment row and a gateway order
  # for exactly the amount owed (computed here, never sent by the app). A retry with the same
  # Idempotency-Key, or while an unpaid order for the same amount exists, reuses it.
  module CreateOrder
    module_function

    def call(booking:, idempotency_key:)
      adapter = Adapters::Payments.adapter
      Booking.transaction do
        booking.lock!
        raise ApplicationError.new(:nothing_to_pay, status: :conflict, details: { status: booking.status }) unless booking.payable?

        amount = booking.outstanding_minor
        open = booking.payments.find_by(method: "online", status: "created", amount_minor: amount)
        next open if open

        payment = booking.payments.create!(method: "online", provider: adapter.name, amount_minor: amount,
                                           currency_code: booking.currency_code, idempotency_key: "order:#{idempotency_key}")
        order = adapter.create_order(amount_minor: amount, currency: booking.currency_code, receipt: payment.public_id,
                                     notes: { booking_id: booking.public_id, payment_id: payment.public_id })
        payment.update!(provider_order_id: order[:id])
        payment
      end
    rescue Adapters::Payments::Error => e
      raise ApplicationError.new(:payment_gateway_error, status: :bad_gateway, details: { reason: e.code })
    end
  end
end
