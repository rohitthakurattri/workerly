module Payments
  # Money arrived (online capture or cash): fix the split, post the ledger, and when the booking
  # is fully paid issue the invoice and mark it paid. Caller holds the booking row lock.
  module Settle
    module_function

    def call(payment, now: Time.current)
      booking = payment.booking
      split = Split.call(booking, payment.amount_minor)
      payment.update!(status: "captured", captured_at: now, commission_minor: split.commission_minor,
                      tax_minor: split.tax_minor, worker_share_minor: split.worker_share_minor)
      payment.online? ? LedgerPostings.captured(payment) : LedgerPostings.cash_recorded(payment)
      booking.update!(paid_minor: booking.paid_minor + payment.amount_minor)
      return payment unless booking.outstanding_minor.zero?

      Invoices::Issue.call(booking, now:)
      if %w[completed disputed].include?(booking.status)
        Bookings::Perform.call(booking:, event: :pay, actor: nil, role: "system", now:)
      else
        ActiveRecord.after_all_transactions_commit do
          BookingChannel.broadcast_to(booking, { type: "booking.updated", id: booking.public_id, status: booking.status, event: "pay" })
        end
      end
      payment
    end
  end
end
