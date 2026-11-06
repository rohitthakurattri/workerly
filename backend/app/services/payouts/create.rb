module Payouts
  # Finance records a bank/UPI transfer to a worker (done outside Workerly until Route, D3).
  # Commission the worker owes on cash jobs is netted first; the payout can't exceed what's left.
  module Create
    module_function

    def call(worker:, amount_minor:, reference:, auth:, currency: "INR", now: Time.current)
      reference = reference.to_s.strip
      raise ApplicationError.new(:reference_required) if reference.empty?

      WorkerProfile.transaction do
        worker.lock!
        balance = Balance.call(worker, currency)
        offset = [ balance.owed_minor, balance.payable_minor ].min
        amount = amount_minor.to_i
        unless amount.positive? && amount <= balance.net_minor
          raise ApplicationError.new(:payout_too_large, details: { available: Shared::Money.to_h([ balance.net_minor, 0 ].max, currency) })
        end

        public_id = SecureRandom.uuid_v7
        if offset.positive?
          Payments::LedgerPostings.payout_offset(worker, offset, currency, key: "payout:#{public_id}:offset", source: worker)
        end
        tx = Payments::LedgerPostings.payout(worker, amount, currency, key: "payout:#{public_id}")
        payout = worker.payouts.create!(public_id:, amount_minor: amount, currency_code: currency, provider_ref: reference,
                                        created_by: auth.user, paid_at: now, ledger_transaction: tx)
        ::Admin::Audit.record!(action: "payout.recorded", target: worker, reason: reference, changes: { amount_minor: amount, offset_minor: offset }, auth:)
        payout
      end
    end
  end
end
