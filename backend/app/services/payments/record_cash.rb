module Payments
  # The worker says the customer paid them in cash. They must confirm the exact amount owed;
  # Workerly's commission becomes a balance the worker owes (netted against future payouts).
  module RecordCash
    module_function

    def call(booking:, worker:, amount_minor:, idempotency_key:, now: Time.current)
      Booking.transaction do
        booking.lock!
        raise ApplicationError.new(:nothing_to_pay, status: :conflict, details: { status: booking.status }) unless booking.payable?
        unless amount_minor.to_i == booking.outstanding_minor
          raise ApplicationError.new(:amount_mismatch, details: { amount_due: Shared::Money.to_h(booking.outstanding_minor, booking.currency_code) })
        end

        payment = booking.payments.create!(method: "cash", provider: "cash", amount_minor: booking.outstanding_minor,
                                           currency_code: booking.currency_code, recorded_by: worker, idempotency_key: "cash:#{idempotency_key}")
        Settle.call(payment, now:)
      end
    end
  end
end
