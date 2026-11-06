module Payments
  # Double-entry postings for money events. Every transaction balances (Ledger::Post refuses
  # otherwise) and is keyed so a replayed webhook or retried job posts nothing new.
  #
  #   online payment captured   Dr gateway_clearing A | Cr platform_revenue C, tax_payable T, worker_payable W
  #   cash recorded by worker   Dr cash_commission_receivable(worker) C+T | Cr platform_revenue C, tax_payable T
  #   refund processed          Dr platform_revenue c, tax_payable t, worker_payable w | Cr gateway_clearing R
  #   payout offset             Dr worker_payable X | Cr cash_commission_receivable X
  #   payout                    Dr worker_payable P | Cr gateway_clearing P
  module LedgerPostings
    module_function

    def account(kind, currency, owner: nil) = Ledger::Account.for(kind, currency_code: currency, owner:)

    def captured(payment)
      cur = payment.currency_code
      worker = payment.booking.worker_profile
      entries = [ { account: account(:gateway_clearing, cur), direction: "debit", amount_minor: payment.amount_minor } ]
      entries << { account: account(:platform_revenue, cur), direction: "credit", amount_minor: payment.commission_minor }
      entries << { account: account(:tax_payable, cur), direction: "credit", amount_minor: payment.tax_minor }
      entries << { account: account(:worker_payable, cur, owner: worker), direction: "credit", amount_minor: payment.worker_share_minor }
      post("payment_captured", "payment:#{payment.id}:captured", payment, entries)
    end

    def cash_recorded(payment)
      cur = payment.currency_code
      owed = payment.commission_minor + payment.tax_minor
      return nil if owed.zero?

      worker = payment.booking.worker_profile
      post("cash_recorded", "payment:#{payment.id}:cash", payment, [
        { account: account(:cash_commission_receivable, cur, owner: worker), direction: "debit", amount_minor: owed },
        { account: account(:platform_revenue, cur), direction: "credit", amount_minor: payment.commission_minor },
        { account: account(:tax_payable, cur), direction: "credit", amount_minor: payment.tax_minor }
      ])
    end

    # Reverses the payment's split in proportion, on cumulative amounts so a full refund
    # reverses it exactly, with no rounding left over.
    def refunded(refund, refunded_before:)
      payment = refund.payment
      cur = payment.currency_code
      share = ->(part, upto) { (upto * part) / payment.amount_minor }
      after = refunded_before + refund.amount_minor
      commission = share.(payment.commission_minor, after) - share.(payment.commission_minor, refunded_before)
      tax = share.(payment.tax_minor, after) - share.(payment.tax_minor, refunded_before)
      worker = refund.amount_minor - commission - tax
      post("refund_processed", "refund:#{refund.id}:processed", refund, [
        { account: account(:platform_revenue, cur), direction: "debit", amount_minor: commission },
        { account: account(:tax_payable, cur), direction: "debit", amount_minor: tax },
        { account: account(:worker_payable, cur, owner: payment.booking.worker_profile), direction: "debit", amount_minor: worker },
        { account: account(:gateway_clearing, cur), direction: "credit", amount_minor: refund.amount_minor }
      ])
    end

    def payout_offset(worker, amount_minor, currency, key:, source:)
      post("payout_offset", key, source, [
        { account: account(:worker_payable, currency, owner: worker), direction: "debit", amount_minor: },
        { account: account(:cash_commission_receivable, currency, owner: worker), direction: "credit", amount_minor: }
      ])
    end

    def payout(worker, amount_minor, currency, key:)
      post("payout", key, worker, [
        { account: account(:worker_payable, currency, owner: worker), direction: "debit", amount_minor: },
        { account: account(:gateway_clearing, currency), direction: "credit", amount_minor: }
      ])
    end

    # Zero-amount lines are dropped (e.g. no tax); the rest must still balance.
    def post(kind, key, source, entries)
      Ledger::Post.call(kind:, idempotency_key: key, source:, entries: entries.reject { |e| e[:amount_minor].zero? })
    end
  end
end
