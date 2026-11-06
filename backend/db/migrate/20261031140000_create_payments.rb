class CreatePayments < ActiveRecord::Migration[8.1]
  def change
    # Commission: most specific rule wins (city + category, then category, then city, then global).
    # D4 defaults: 10% of labour, no fixed fee. Snapshotted onto each booking at confirmation.
    create_table :commission_rules do |t|
      t.references :city, foreign_key: true
      t.references :service_category, foreign_key: true
      t.integer :percent_bps, null: false
      t.bigint :fixed_minor, null: false, default: 0
      t.datetime :effective_from, null: false
      t.references :created_by, foreign_key: { to_table: :users }
      t.timestamps
    end
    add_index :commission_rules, %i[city_id service_category_id effective_from], unique: true, nulls_not_distinct: true,
      name: "index_commission_rules_uniqueness"
    add_check_constraint :commission_rules, "percent_bps BETWEEN 0 AND 5000", name: "commission_rules_percent_check"
    add_check_constraint :commission_rules, "fixed_minor >= 0", name: "commission_rules_fixed_check"

    add_column :bookings, :commission_bps, :integer
    add_column :bookings, :commission_fixed_minor, :bigint
    add_column :bookings, :paid_minor, :bigint, null: false, default: 0

    create_table :payments do |t|
      t.uuid :public_id, null: false
      t.references :booking, null: false, foreign_key: true
      t.string :method, null: false                     # online | cash
      t.string :provider, null: false                   # razorpay | fake | cash
      t.string :provider_order_id
      t.string :provider_payment_id
      t.bigint :amount_minor, null: false
      t.string :currency_code, limit: 3, null: false
      t.string :status, null: false, default: "created"
      t.bigint :refunded_minor, null: false, default: 0
      # The split, fixed when the payment is captured (what the ledger posted).
      t.bigint :commission_minor
      t.bigint :tax_minor
      t.bigint :worker_share_minor
      t.string :idempotency_key, null: false
      t.references :recorded_by, foreign_key: { to_table: :users } # cash: the worker
      t.datetime :captured_at
      t.datetime :failed_at
      t.string :failure_reason
      t.timestamps
    end
    add_index :payments, :public_id, unique: true
    add_index :payments, :provider_order_id, unique: true
    add_index :payments, :provider_payment_id, unique: true
    add_index :payments, :idempotency_key, unique: true
    add_check_constraint :payments, "method IN ('online','cash')", name: "payments_method_check"
    add_check_constraint :payments, "status IN ('created','captured','failed','refunded','partially_refunded','amount_mismatch')", name: "payments_status_check"
    add_check_constraint :payments, "amount_minor > 0 AND refunded_minor >= 0 AND refunded_minor <= amount_minor", name: "payments_amounts_check"

    # Every webhook as received. The unique index makes a redelivered event a no-op.
    create_table :payment_events do |t|
      t.string :provider, null: false
      t.string :provider_event_id, null: false
      t.string :event_type, null: false
      t.jsonb :payload, null: false
      t.boolean :signature_valid, null: false
      t.datetime :processed_at
      t.string :error
      t.datetime :created_at, null: false
    end
    add_index :payment_events, %i[provider provider_event_id], unique: true
    add_index :payment_events, %i[processed_at created_at]

    create_table :refunds do |t|
      t.uuid :public_id, null: false
      t.references :payment, null: false, foreign_key: true
      t.bigint :amount_minor, null: false
      t.string :reason, null: false
      t.string :status, null: false, default: "pending"
      t.string :provider_refund_id
      t.references :initiated_by, null: false, foreign_key: { to_table: :users }
      t.datetime :processed_at
      t.timestamps
    end
    add_index :refunds, :public_id, unique: true
    add_index :refunds, :provider_refund_id, unique: true
    add_check_constraint :refunds, "amount_minor > 0", name: "refunds_amount_check"
    add_check_constraint :refunds, "status IN ('pending','processed','failed')", name: "refunds_status_check"

    # Gapless numbers per financial year (April–March), e.g. WK/2026-27/000042.
    create_table :invoice_sequences do |t|
      t.string :series, null: false
      t.integer :last_number, null: false, default: 0
    end
    add_index :invoice_sequences, :series, unique: true

    create_table :invoices do |t|
      t.uuid :public_id, null: false
      t.references :booking, null: false, foreign_key: true, index: { unique: true }
      t.string :number, null: false
      t.datetime :issued_at, null: false
      t.string :currency_code, limit: 3, null: false
      t.bigint :subtotal_minor, null: false
      t.bigint :tax_minor, null: false
      t.bigint :total_minor, null: false
      t.jsonb :lines, null: false, default: []
      t.jsonb :parties, null: false, default: {}
      t.datetime :created_at, null: false
    end
    add_index :invoices, :public_id, unique: true
    add_index :invoices, :number, unique: true

    # Payouts are bank/UPI transfers done by finance (manual until Route, D3), recorded here.
    create_table :worker_payouts do |t|
      t.uuid :public_id, null: false
      t.references :worker_profile, null: false, foreign_key: true
      t.bigint :amount_minor, null: false
      t.string :currency_code, limit: 3, null: false
      t.string :status, null: false, default: "paid"
      t.string :provider_ref, null: false
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.references :ledger_transaction, foreign_key: true
      t.datetime :paid_at, null: false
      t.datetime :created_at, null: false
    end
    add_index :worker_payouts, :public_id, unique: true
    add_check_constraint :worker_payouts, "amount_minor > 0", name: "worker_payouts_amount_check"
    add_check_constraint :worker_payouts, "status IN ('paid')", name: "worker_payouts_status_check"
  end
end
