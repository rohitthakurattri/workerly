module Ledger
  class Entry < ApplicationRecord
    include AppendOnly

    DIRECTIONS = %w[debit credit].freeze

    belongs_to :ledger_transaction, class_name: "Ledger::Transaction"
    belongs_to :account, class_name: "Ledger::Account", foreign_key: :ledger_account_id, inverse_of: :entries

    validates :direction, inclusion: { in: DIRECTIONS }
    validates :amount_minor, numericality: { only_integer: true, greater_than: 0 }
  end
end
