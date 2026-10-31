module Ledger
  # A balance bucket. Platform accounts have no owner; worker_payable is owned by a WorkerProfile.
  class Account < ApplicationRecord
    KINDS = %w[worker_payable platform_revenue gateway_clearing cash_commission_receivable tax_payable customer_refunds].freeze

    belongs_to :owner, polymorphic: true, optional: true
    has_many :entries, class_name: "Ledger::Entry", foreign_key: :ledger_account_id, inverse_of: :account, dependent: :restrict_with_error

    validates :kind, inclusion: { in: KINDS }
    validates :currency_code, length: { is: 3 }

    def self.for(kind, currency_code:, owner: nil)
      find_or_create_by!(kind: kind.to_s, currency_code:, owner_type: owner&.class&.name, owner_id: owner&.id)
    rescue ActiveRecord::RecordNotUnique
      retry
    end

    # Debits minus credits, in minor units.
    def balance_minor
      entries.sum(Arel.sql("CASE direction WHEN 'debit' THEN amount_minor ELSE -amount_minor END")).to_i
    end
  end
end
