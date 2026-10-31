class CreateQuotations < ActiveRecord::Migration[8.1]
  def change
    # One quotation per invited worker per request. Prices live in revisions, never on the quotation.
    create_table :quotations do |t|
      t.uuid :public_id, null: false
      t.references :service_request, null: false, foreign_key: true, index: false
      t.references :worker_profile, null: false, foreign_key: true, index: false
      t.references :request_invitation, null: false, foreign_key: true, index: { unique: true } # only invited workers quote
      t.string :kind, null: false                        # fixed | inspection
      t.string :status, null: false, default: "submitted"
      t.integer :current_version, null: false, default: 1
      t.datetime :valid_until, null: false
      t.datetime :accepted_at
      t.datetime :declined_at
      t.string :decline_reason                           # customer's words, or another_accepted
      t.datetime :withdrawn_at
      t.timestamps
    end
    add_index :quotations, :public_id, unique: true
    add_index :quotations, %i[service_request_id worker_profile_id], unique: true
    add_index :quotations, %i[worker_profile_id created_at]
    # At most one accepted quotation per request, whatever happens in the app.
    add_index :quotations, :service_request_id, unique: true, where: "status = 'accepted'", name: "index_quotations_one_accepted_per_request"
    add_check_constraint :quotations, "kind IN ('fixed','inspection')", name: "quotations_kind_check"
    add_check_constraint :quotations, "status IN ('submitted','accepted','declined','withdrawn','expired')", name: "quotations_status_check"
    add_check_constraint :quotations, "current_version > 0", name: "quotations_version_check"
    add_check_constraint :quotations, "status <> 'accepted' OR accepted_at IS NOT NULL", name: "quotations_accepted_check"

    # Every change to a price is a new row. Rows are never updated: a booking approval points at
    # the exact revision the customer saw.
    create_table :quotation_revisions do |t|
      t.uuid :public_id, null: false
      t.references :quotation, null: false, foreign_key: true, index: false
      t.integer :version, null: false
      t.string :stage, null: false                       # initial | inspection_fee | final | change_order
      t.bigint :subtotal_minor, null: false
      t.integer :tax_rate_bps, null: false, default: 0
      t.bigint :tax_minor, null: false, default: 0
      t.bigint :total_minor, null: false
      t.string :currency_code, limit: 3, null: false
      t.text :notes
      t.integer :estimated_minutes
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.datetime :created_at, null: false
    end
    add_index :quotation_revisions, :public_id, unique: true
    add_index :quotation_revisions, %i[quotation_id version], unique: true
    add_check_constraint :quotation_revisions, "version > 0", name: "quotation_revisions_version_check"
    add_check_constraint :quotation_revisions, "stage IN ('initial','inspection_fee','final','change_order')", name: "quotation_revisions_stage_check"
    add_check_constraint :quotation_revisions, "subtotal_minor >= 0 AND tax_minor >= 0 AND total_minor = subtotal_minor + tax_minor",
      name: "quotation_revisions_totals_check"
    add_check_constraint :quotation_revisions, "tax_rate_bps BETWEEN 0 AND 5000", name: "quotation_revisions_tax_rate_check"
    add_check_constraint :quotation_revisions, "estimated_minutes IS NULL OR estimated_minutes BETWEEN 1 AND 20160",
      name: "quotation_revisions_estimate_check"

    create_table :quotation_items do |t|
      t.references :quotation_revision, null: false, foreign_key: true
      t.integer :position, null: false
      t.string :item_type, null: false                   # labour | material | transport | inspection | other
      t.string :description, null: false
      t.string :brand
      t.decimal :quantity, precision: 10, scale: 3, null: false
      t.string :unit, null: false
      t.bigint :unit_price_minor, null: false
      t.string :condition                                # new | refurbished | used (materials)
      t.integer :warranty_days
      t.bigint :amount_minor, null: false
    end
    add_index :quotation_items, %i[quotation_revision_id position], unique: true
    add_check_constraint :quotation_items, "quantity > 0", name: "quotation_items_quantity_check"
    add_check_constraint :quotation_items, "unit_price_minor >= 0 AND amount_minor >= 0", name: "quotation_items_price_check"
    add_check_constraint :quotation_items, "item_type IN ('labour','material','transport','inspection','other')", name: "quotation_items_type_check"
    add_check_constraint :quotation_items, "condition IS NULL OR condition IN ('new','refurbished','used')", name: "quotation_items_condition_check"
    add_check_constraint :quotation_items, "warranty_days IS NULL OR warranty_days BETWEEN 0 AND 3650", name: "quotation_items_warranty_check"

    # GST and similar taxes differ by service; 0 until the CA's opinion (plan risk table).
    add_column :service_categories, :tax_rate_bps, :integer, null: false, default: 0
    add_check_constraint :service_categories, "tax_rate_bps BETWEEN 0 AND 5000", name: "service_categories_tax_rate_check"
  end
end
