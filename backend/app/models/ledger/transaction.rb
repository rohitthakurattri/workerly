module Ledger
  class Transaction < ApplicationRecord
    include AppendOnly

    has_public_id
    belongs_to :source, polymorphic: true, optional: true
    has_many :entries, class_name: "Ledger::Entry", foreign_key: :ledger_transaction_id, inverse_of: :ledger_transaction,
                       dependent: nil

    validates :kind, :idempotency_key, presence: true
  end
end
