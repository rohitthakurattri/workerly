module Payments
  # The gateway says money was captured (signed webhook). Safe to call any number of times: the
  # payment row lock and its status make the second call a no-op, and ledger postings are keyed.
  module Capture
    module_function

    def call(payment:, provider_payment_id:, amount_minor:, currency:, now: Time.current)
      Booking.transaction do
        payment.booking.lock!
        payment.lock!
        next payment if payment.settled? || payment.amount_mismatch?

        if amount_minor.to_i != payment.amount_minor || currency != payment.currency_code
          # Never post money we didn't ask for; finance sees it on the reconciliation report.
          next payment.tap { |p| p.update!(status: "amount_mismatch", provider_payment_id:, failure_reason: "got #{amount_minor} #{currency}") }
        end

        payment.update!(provider_payment_id:)
        Settle.call(payment, now:)
      end
    end
  end
end
