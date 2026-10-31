class CreateBookings < ActiveRecord::Migration[8.1]
  def change
    create_table :bookings do |t|
      t.uuid :public_id, null: false
      t.references :service_request, null: false, foreign_key: true, index: false
      t.references :quotation, null: false, foreign_key: true, index: false
      t.references :customer, null: false, foreign_key: { to_table: :users }
      t.references :worker_profile, null: false, foreign_key: true, index: false
      t.string :kind, null: false                        # copied from the quotation
      t.string :status, null: false, default: "confirmed"
      # What the customer has approved so far (sum of approved revisions); Phase 6 adds to it.
      t.bigint :approved_total_minor, null: false
      t.string :currency_code, limit: 3, null: false
      t.datetime :confirmed_at, null: false
      t.datetime :address_revealed_at
      t.datetime :scheduled_at
      t.datetime :started_at
      t.datetime :completed_at
      t.datetime :cancelled_at
      t.string :cancelled_by                              # customer | worker | admin
      t.string :cancel_reason
      t.timestamps
    end
    add_index :bookings, :public_id, unique: true
    # One active booking per request: the second of two simultaneous accepts fails here.
    add_index :bookings, :service_request_id, unique: true, where: "status NOT IN ('cancelled','rejected')",
      name: "index_bookings_one_active_per_request"
    add_index :bookings, :quotation_id, unique: true
    add_index :bookings, %i[worker_profile_id created_at]
    add_check_constraint :bookings, "kind IN ('fixed','inspection')", name: "bookings_kind_check"
    add_check_constraint :bookings, <<~SQL.squish, name: "bookings_status_check"
      status IN ('confirmed','inspection_scheduled','inspecting','awaiting_final_approval','closed_after_inspection',
                 'scheduled','in_progress','awaiting_change_approval','completed','paid','cancelled','rejected',
                 'disputed','refunded')
    SQL
    add_check_constraint :bookings, "approved_total_minor >= 0", name: "bookings_amount_check"
    add_check_constraint :bookings, "cancelled_by IS NULL OR cancelled_by IN ('customer','worker','admin')", name: "bookings_cancelled_by_check"

    # Append-only: every booking status change, who made it and as which role.
    create_table :booking_status_histories do |t|
      t.references :booking, null: false, foreign_key: true
      t.string :from_status
      t.string :to_status, null: false
      t.references :actor, foreign_key: { to_table: :users }
      t.string :actor_role
      t.jsonb :metadata, null: false, default: {}
      t.datetime :created_at, null: false
    end

    # Proof of consent: the customer approved (or rejected) exactly this revision, once.
    create_table :booking_approvals do |t|
      t.references :booking, null: false, foreign_key: true
      t.references :quotation_revision, null: false, foreign_key: true, index: { unique: true }
      t.string :decision, null: false
      t.references :decided_by, null: false, foreign_key: { to_table: :users }
      t.inet :ip
      t.string :user_agent
      t.datetime :created_at, null: false
    end
    add_check_constraint :booking_approvals, "decision IN ('approved','rejected')", name: "booking_approvals_decision_check"
  end
end
