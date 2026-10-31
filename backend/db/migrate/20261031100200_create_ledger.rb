class CreateLedger < ActiveRecord::Migration[8.1]
  def change
    # Double-entry ledger (schema only in Phase 5; postings start with payments in Phase 7).
    # Platform accounts have no owner; worker accounts are owned by the worker profile.
    create_table :ledger_accounts do |t|
      t.string :owner_type
      t.bigint :owner_id
      t.string :kind, null: false
      t.string :currency_code, limit: 3, null: false
      t.timestamps
    end
    add_index :ledger_accounts, %i[owner_type owner_id kind currency_code], unique: true, nulls_not_distinct: true,
      name: "index_ledger_accounts_uniqueness"
    add_check_constraint :ledger_accounts, <<~SQL.squish, name: "ledger_accounts_kind_check"
      kind IN ('worker_payable','platform_revenue','gateway_clearing','cash_commission_receivable','tax_payable','customer_refunds')
    SQL
    add_check_constraint :ledger_accounts, "(owner_type IS NULL) = (owner_id IS NULL)", name: "ledger_accounts_owner_check"

    create_table :ledger_transactions do |t|
      t.uuid :public_id, null: false
      t.string :kind, null: false
      t.string :idempotency_key, null: false
      t.string :source_type
      t.bigint :source_id
      t.string :description
      t.datetime :posted_at, null: false
      t.datetime :created_at, null: false
    end
    add_index :ledger_transactions, :public_id, unique: true
    add_index :ledger_transactions, :idempotency_key, unique: true
    add_index :ledger_transactions, %i[source_type source_id]

    create_table :ledger_entries do |t|
      t.references :ledger_transaction, null: false, foreign_key: true
      t.references :ledger_account, null: false, foreign_key: true, index: false
      t.string :direction, null: false
      t.bigint :amount_minor, null: false
      t.string :currency_code, limit: 3, null: false
      t.datetime :created_at, null: false
    end
    add_index :ledger_entries, %i[ledger_account_id created_at]
    add_check_constraint :ledger_entries, "direction IN ('debit','credit')", name: "ledger_entries_direction_check"
    add_check_constraint :ledger_entries, "amount_minor > 0", name: "ledger_entries_amount_check"
  end
end
