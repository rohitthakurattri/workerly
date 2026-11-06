module Payouts
  # A worker's money position from the ledger, in minor units:
  #   payable     what Workerly holds for them (online payments, less commission and refunds)
  #   owed        commission they owe on cash jobs
  #   net         payable − owed: what a payout can be
  module Balance
    module_function

    Result = Data.define(:payable_minor, :owed_minor, :net_minor, :currency)

    def call(worker, currency = "INR")
      payable = -account_balance(worker, :worker_payable, currency)
      owed = account_balance(worker, :cash_commission_receivable, currency)
      Result.new(payable_minor: payable, owed_minor: owed, net_minor: payable - owed, currency:)
    end

    def account_balance(worker, kind, currency)
      Ledger::Account.find_by(owner: worker, kind: kind.to_s, currency_code: currency)&.balance_minor || 0
    end
  end
end
