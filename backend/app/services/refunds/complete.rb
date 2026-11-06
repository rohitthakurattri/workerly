module Refunds
  # A refund went through: reverse its share of the split and update the payment (and the
  # booking, when everything was returned). Idempotent.
  module Complete
    module_function

    def call(refund:, now: Time.current)
      Booking.transaction do
        payment = refund.payment
        booking = payment.booking
        booking.lock!
        payment.lock!
        refund.lock!
        next refund if refund.processed?

        refunded_before = payment.refunded_minor
        refund.update!(status: "processed", processed_at: now)
        Payments::LedgerPostings.refunded(refund, refunded_before:)
        payment.update!(refunded_minor: refunded_before + refund.amount_minor)
        payment.update!(status: payment.refunded_minor == payment.amount_minor ? "refunded" : "partially_refunded")

        fully = booking.payments.settled.sum(:refunded_minor) >= booking.paid_minor
        if fully && %w[paid disputed].include?(booking.status)
          Bookings::Perform.call(booking:, event: :refund, actor: nil, role: "system", now:)
        end
        refund
      end
    end
  end
end
