module Finance
  # The daily check finance runs: does the ledger agree with itself and with the payments?
  # Everything in one currency per report.
  module Reconciliation
    module_function

    def call(from:, to:, currency: "INR")
      range = from..to
      payments = Payment.where(currency_code: currency, captured_at: range)
      online = payments.where(method: "online").settled
      refunds = Refund.joins(:payment).where(payments: { currency_code: currency }, status: "processed", processed_at: range)
      payouts = WorkerPayout.where(currency_code: currency, paid_at: range)
      entries = Ledger::Entry.where(currency_code: currency)
      debits = entries.where(direction: "debit").sum(:amount_minor)
      credits = entries.where(direction: "credit").sum(:amount_minor)
      totals = Ledger::Account.where(currency_code: currency).group(:kind).joins(:entries)
                              .sum(Arel.sql("CASE ledger_entries.direction WHEN 'debit' THEN ledger_entries.amount_minor ELSE -ledger_entries.amount_minor END"))

      unposted = Payment.settled.where(currency_code: currency)
                        .where.not(id: Ledger::Transaction.where(source_type: "Payment").select(:source_id))
                        .where("commission_minor + tax_minor > 0 OR method = 'online'")
      {
        currency:, from: from.iso8601, to: to.iso8601,
        online_captured_minor: online.sum(:amount_minor), cash_recorded_minor: payments.where(method: "cash").sum(:amount_minor),
        refunded_minor: refunds.sum(:amount_minor), payouts_minor: payouts.sum(:amount_minor),
        commission_minor: payments.sum(:commission_minor), tax_minor: payments.sum(:tax_minor),
        balances: Ledger::Account::KINDS.index_with { |k| totals[k].to_i },
        ledger_balanced: debits == credits, ledger_debits_minor: debits, ledger_credits_minor: credits,
        issues: {
          payments_without_ledger: unposted.limit(50).pluck(:public_id),
          amount_mismatches: Payment.where(status: "amount_mismatch", currency_code: currency).limit(50).pluck(:public_id),
          pending_refunds: Refund.where(status: "pending").where(created_at: ...1.day.ago).limit(50).pluck(:public_id),
          stale_orders: Payment.where(status: "created", created_at: ...1.day.ago).count
        }
      }
    end
  end
end
