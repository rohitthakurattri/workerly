class CreateBookingLifecycle < ActiveRecord::Migration[8.1]
  def change
    # Phase 6: the booking lifecycle. approved_total_minor now means "what the customer owes",
    # recomputed only from approved revisions (Bookings::AmountDue).
    add_column :bookings, :checked_in_at, :datetime
    add_reference :bookings, :pending_revision, foreign_key: { to_table: :quotation_revisions }, index: false
    add_column :bookings, :status_before_dispute, :string

    # A booking closed after an inspection no longer blocks a new booking for the reopened request.
    remove_index :bookings, name: "index_bookings_one_active_per_request"
    add_index :bookings, :service_request_id, unique: true, where: "status NOT IN ('cancelled','rejected','closed_after_inspection')",
      name: "index_bookings_one_active_per_request"
    add_index :bookings, %i[status scheduled_at]

    # In-booking chat, so neither side has to move to WhatsApp.
    create_table :messages do |t|
      t.uuid :public_id, null: false
      t.references :booking, null: false, foreign_key: true, index: false
      t.references :sender, null: false, foreign_key: { to_table: :users }
      t.string :sender_role, null: false
      t.text :body, null: false
      t.datetime :created_at, null: false
    end
    add_index :messages, :public_id, unique: true
    add_index :messages, %i[booking_id created_at]
    add_check_constraint :messages, "sender_role IN ('customer','worker')", name: "messages_sender_role_check"
    add_check_constraint :messages, "char_length(body) BETWEEN 1 AND 2000", name: "messages_body_check"

    # One review per booking, only after the work is done.
    create_table :reviews do |t|
      t.uuid :public_id, null: false
      t.references :booking, null: false, foreign_key: true, index: { unique: true }
      t.references :reviewer, null: false, foreign_key: { to_table: :users }
      t.references :worker_profile, null: false, foreign_key: true, index: false
      t.integer :rating, null: false
      t.text :body
      t.datetime :created_at, null: false
    end
    add_index :reviews, :public_id, unique: true
    add_index :reviews, %i[worker_profile_id created_at]
    add_check_constraint :reviews, "rating BETWEEN 1 AND 5", name: "reviews_rating_check"

    create_table :disputes do |t|
      t.uuid :public_id, null: false
      t.references :booking, null: false, foreign_key: true, index: false
      t.references :raised_by, null: false, foreign_key: { to_table: :users }
      t.string :category, null: false
      t.text :description, null: false
      t.string :status, null: false, default: "open"
      t.text :resolution
      t.references :resolved_by, foreign_key: { to_table: :users }
      t.datetime :resolved_at
      t.timestamps
    end
    add_index :disputes, :public_id, unique: true
    add_index :disputes, :booking_id, unique: true, where: "status = 'open'", name: "index_disputes_one_open_per_booking"
    add_index :disputes, %i[status created_at]
    add_check_constraint :disputes, "category IN ('no_show','quality','overcharge','damage','behaviour','other')", name: "disputes_category_check"
    add_check_constraint :disputes, "status IN ('open','resolved')", name: "disputes_status_check"
    add_check_constraint :disputes, "status <> 'resolved' OR (resolved_at IS NOT NULL AND resolution IS NOT NULL)", name: "disputes_resolved_check"
  end
end
