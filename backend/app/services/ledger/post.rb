module Ledger
  # Posts one balanced, idempotent transaction. Phase 7 (payments) is the first caller.
  #
  #   Ledger::Post.call(kind: "job_payment", idempotency_key: "payment:42:captured", source: payment, entries: [
  #     { account: clearing, direction: "debit", amount_minor: 199_900 },
  #     { account: worker_payable, direction: "credit", amount_minor: 179_910 },
  #     { account: revenue, direction: "credit", amount_minor: 19_990 }
  #   ])
  #
  # Replaying the same key returns the original transaction; a different body under the same key
  # is an error. Debits must equal credits per currency.
  module Post
    module_function

    class Unbalanced < StandardError; end
    class KeyReused < StandardError; end

    def call(kind:, idempotency_key:, entries:, source: nil, description: nil, posted_at: Time.current)
      existing = Transaction.find_by(idempotency_key:)
      return verify_replay!(existing, entries) if existing

      check_balanced!(entries)
      Transaction.transaction(requires_new: true) do
        tx = Transaction.create!(kind:, idempotency_key:, source:, description:, posted_at:)
        entries.each do |e|
          Entry.create!(ledger_transaction: tx, account: e[:account], direction: e[:direction].to_s,
                        amount_minor: e[:amount_minor], currency_code: e[:account].currency_code)
        end
        tx
      end
    rescue ActiveRecord::RecordNotUnique
      verify_replay!(Transaction.find_by!(idempotency_key:), entries)
    end

    def check_balanced!(entries)
      raise Unbalanced, "a transaction needs at least two entries" if entries.size < 2
      raise Unbalanced, "amounts must be positive integers" unless entries.all? { |e| e[:amount_minor].is_a?(Integer) && e[:amount_minor].positive? }

      entries.group_by { |e| e[:account].currency_code }.each do |currency, list|
        debits = list.select { |e| e[:direction].to_s == "debit" }.sum { |e| e[:amount_minor] }
        credits = list.select { |e| e[:direction].to_s == "credit" }.sum { |e| e[:amount_minor] }
        raise Unbalanced, "#{currency}: debits #{debits} != credits #{credits}" unless debits == credits
      end
    end

    def verify_replay!(tx, entries)
      signature = ->(list) { list.map { |e| [ e[:account].id, e[:direction].to_s, e[:amount_minor] ] }.sort }
      stored = tx.entries.map { |e| { account: e.account, direction: e.direction, amount_minor: e.amount_minor } }
      raise KeyReused, "idempotency key #{tx.idempotency_key} was used for different entries" unless signature.(stored) == signature.(entries)

      tx
    end
  end
end
