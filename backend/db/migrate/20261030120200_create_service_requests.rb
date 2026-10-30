class CreateServiceRequests < ActiveRecord::Migration[8.1]
  def change
    create_table :service_requests do |t|
      t.uuid :public_id, null: false
      t.references :customer, null: false, foreign_key: { to_table: :users }, index: false
      t.references :service_category, foreign_key: true, index: false
      t.references :address, foreign_key: true
      t.text :description
      t.jsonb :answers, null: false, default: []             # [{ question, answer }] from follow-up questions
      t.references :triage_analysis, foreign_key: { to_table: :ai_analyses }, index: false
      t.text :ai_summary                                     # shown labelled as AI-written, next to the customer's words
      t.string :category_source                              # ai (accepted the suggestion) | customer (picked another)
      t.boolean :safety_flag, null: false, default: false
      t.string :urgency, null: false, default: "flexible"
      t.datetime :preferred_from
      t.datetime :preferred_to
      # Copied from the address at submit, so later edits to the address book never move a live request.
      t.references :city, foreign_key: true, index: false
      t.st_point :location, geographic: true, srid: 4326
      t.jsonb :address_snapshot
      t.string :status, null: false, default: "draft"
      t.datetime :submitted_at
      t.datetime :expires_at
      t.datetime :cancelled_at
      t.string :cancel_reason
      t.timestamps
    end
    add_index :service_requests, :public_id, unique: true
    add_index :service_requests, %i[customer_id created_at]
    add_index :service_requests, %i[status service_category_id]
    add_index :service_requests, %i[status expires_at]
    add_index :service_requests, :location, using: :gist
    add_check_constraint :service_requests,
      "status IN ('draft','open','quoting','booked','fulfilled','expired','cancelled')", name: "service_requests_status_check"
    add_check_constraint :service_requests, "urgency IN ('asap','today','this_week','flexible')",
      name: "service_requests_urgency_check"
    add_check_constraint :service_requests, "category_source IS NULL OR category_source IN ('ai','customer')",
      name: "service_requests_category_source_check"
    # Anything past draft must be complete enough for matching.
    add_check_constraint :service_requests,
      "status = 'draft' OR (service_category_id IS NOT NULL AND address_id IS NOT NULL AND city_id IS NOT NULL " \
      "AND location IS NOT NULL AND address_snapshot IS NOT NULL AND submitted_at IS NOT NULL AND expires_at IS NOT NULL)",
      name: "service_requests_submitted_complete_check"
    add_check_constraint :service_requests,
      "preferred_from IS NULL OR preferred_to IS NULL OR preferred_to > preferred_from", name: "service_requests_window_check"
    add_check_constraint :service_requests, "status <> 'cancelled' OR cancelled_at IS NOT NULL",
      name: "service_requests_cancelled_check"

    create_table :request_attachments do |t|
      t.uuid :public_id, null: false
      t.references :service_request, null: false, foreign_key: true
      t.string :kind, null: false, default: "image"          # image now; audio and video arrive with Phase 8
      t.integer :width
      t.integer :height
      t.text :transcript
      t.timestamps
    end
    add_index :request_attachments, :public_id, unique: true
    add_check_constraint :request_attachments, "kind IN ('image','audio','video')", name: "request_attachments_kind_check"
  end
end
