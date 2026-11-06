class WorkerPayout < ApplicationRecord
  include AppendOnly

  has_public_id
  belongs_to :worker_profile
  belongs_to :created_by, class_name: "User"
  belongs_to :ledger_transaction, class_name: "Ledger::Transaction", optional: true

  validates :amount_minor, numericality: { only_integer: true, greater_than: 0 }
  validates :provider_ref, presence: true, length: { maximum: 100 }
end
