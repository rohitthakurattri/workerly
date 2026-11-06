# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_10_31_140000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "citext"
  enable_extension "pg_catalog.plpgsql"
  enable_extension "postgis"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "addresses", force: :cascade do |t|
    t.uuid "public_id", null: false
    t.bigint "user_id", null: false
    t.bigint "city_id", null: false
    t.string "label"
    t.string "line1", null: false
    t.string "line2"
    t.string "landmark"
    t.string "locality", null: false
    t.string "pincode", null: false
    t.geography "location", limit: {srid: 4326, type: "st_point", geographic: true}, null: false
    t.boolean "is_default", default: false, null: false
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["city_id"], name: "index_addresses_on_city_id"
    t.index ["location"], name: "index_addresses_on_location", using: :gist
    t.index ["public_id"], name: "index_addresses_on_public_id", unique: true
    t.index ["user_id", "created_at"], name: "index_addresses_on_user_id_and_created_at", where: "(deleted_at IS NULL)"
    t.index ["user_id"], name: "index_addresses_one_default_per_user", unique: true, where: "(is_default AND (deleted_at IS NULL))"
    t.check_constraint "pincode::text ~ '^[1-9][0-9]{5}$'::text", name: "addresses_pincode_check"
  end

  create_table "admin_actions", force: :cascade do |t|
    t.bigint "admin_id", null: false
    t.string "admin_role", null: false
    t.string "action", null: false
    t.string "target_type", null: false
    t.bigint "target_id", null: false
    t.jsonb "changes_made", default: {}, null: false
    t.text "reason"
    t.inet "ip"
    t.string "user_agent"
    t.string "request_id"
    t.datetime "created_at", null: false
    t.index ["admin_id"], name: "index_admin_actions_on_admin_id"
    t.index ["created_at"], name: "index_admin_actions_on_created_at"
    t.index ["target_type", "target_id"], name: "index_admin_actions_on_target_type_and_target_id"
  end

  create_table "ai_analyses", force: :cascade do |t|
    t.uuid "public_id", null: false
    t.string "analysable_type", null: false
    t.bigint "analysable_id", null: false
    t.bigint "user_id"
    t.string "use_case", null: false
    t.string "provider", null: false
    t.string "model"
    t.string "prompt_version", null: false
    t.string "input_hash", null: false
    t.string "status", null: false
    t.boolean "cached", default: false, null: false
    t.jsonb "output"
    t.bigint "suggested_category_id"
    t.decimal "confidence", precision: 4, scale: 3
    t.integer "input_tokens"
    t.integer "output_tokens"
    t.bigint "cost_micros"
    t.string "currency_code", limit: 3
    t.integer "latency_ms"
    t.string "error_code"
    t.datetime "created_at", null: false
    t.index ["analysable_type", "analysable_id"], name: "index_ai_analyses_on_analysable"
    t.index ["provider", "status", "created_at"], name: "index_ai_analyses_on_provider_and_status_and_created_at"
    t.index ["public_id"], name: "index_ai_analyses_on_public_id", unique: true
    t.index ["use_case", "input_hash", "created_at"], name: "index_ai_analyses_on_use_case_and_input_hash_and_created_at"
    t.index ["user_id", "use_case", "created_at"], name: "index_ai_analyses_on_user_id_and_use_case_and_created_at"
    t.check_constraint "confidence IS NULL OR confidence >= 0::numeric AND confidence <= 1::numeric", name: "ai_analyses_confidence_check"
    t.check_constraint "status::text = ANY (ARRAY['succeeded'::character varying, 'failed'::character varying]::text[])", name: "ai_analyses_status_check"
  end

  create_table "booking_approvals", force: :cascade do |t|
    t.bigint "booking_id", null: false
    t.bigint "quotation_revision_id", null: false
    t.string "decision", null: false
    t.bigint "decided_by_id", null: false
    t.inet "ip"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.index ["booking_id"], name: "index_booking_approvals_on_booking_id"
    t.index ["decided_by_id"], name: "index_booking_approvals_on_decided_by_id"
    t.index ["quotation_revision_id"], name: "index_booking_approvals_on_quotation_revision_id", unique: true
    t.check_constraint "decision::text = ANY (ARRAY['approved'::character varying, 'rejected'::character varying]::text[])", name: "booking_approvals_decision_check"
  end

  create_table "booking_status_histories", force: :cascade do |t|
    t.bigint "booking_id", null: false
    t.string "from_status"
    t.string "to_status", null: false
    t.bigint "actor_id"
    t.string "actor_role"
    t.jsonb "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.index ["actor_id"], name: "index_booking_status_histories_on_actor_id"
    t.index ["booking_id"], name: "index_booking_status_histories_on_booking_id"
  end

  create_table "bookings", force: :cascade do |t|
    t.uuid "public_id", null: false
    t.bigint "service_request_id", null: false
    t.bigint "quotation_id", null: false
    t.bigint "customer_id", null: false
    t.bigint "worker_profile_id", null: false
    t.string "kind", null: false
    t.string "status", default: "confirmed", null: false
    t.bigint "approved_total_minor", null: false
    t.string "currency_code", limit: 3, null: false
    t.datetime "confirmed_at", null: false
    t.datetime "address_revealed_at"
    t.datetime "scheduled_at"
    t.datetime "started_at"
    t.datetime "completed_at"
    t.datetime "cancelled_at"
    t.string "cancelled_by"
    t.string "cancel_reason"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "checked_in_at"
    t.bigint "pending_revision_id"
    t.string "status_before_dispute"
    t.integer "commission_bps"
    t.bigint "commission_fixed_minor"
    t.bigint "paid_minor", default: 0, null: false
    t.index ["customer_id"], name: "index_bookings_on_customer_id"
    t.index ["public_id"], name: "index_bookings_on_public_id", unique: true
    t.index ["quotation_id"], name: "index_bookings_on_quotation_id", unique: true
    t.index ["service_request_id"], name: "index_bookings_one_active_per_request", unique: true, where: "((status)::text <> ALL ((ARRAY['cancelled'::character varying, 'rejected'::character varying, 'closed_after_inspection'::character varying])::text[]))"
    t.index ["status", "scheduled_at"], name: "index_bookings_on_status_and_scheduled_at"
    t.index ["worker_profile_id", "created_at"], name: "index_bookings_on_worker_profile_id_and_created_at"
    t.check_constraint "approved_total_minor >= 0", name: "bookings_amount_check"
    t.check_constraint "cancelled_by IS NULL OR (cancelled_by::text = ANY (ARRAY['customer'::character varying, 'worker'::character varying, 'admin'::character varying]::text[]))", name: "bookings_cancelled_by_check"
    t.check_constraint "kind::text = ANY (ARRAY['fixed'::character varying, 'inspection'::character varying]::text[])", name: "bookings_kind_check"
    t.check_constraint "status::text = ANY (ARRAY['confirmed'::character varying, 'inspection_scheduled'::character varying, 'inspecting'::character varying, 'awaiting_final_approval'::character varying, 'closed_after_inspection'::character varying, 'scheduled'::character varying, 'in_progress'::character varying, 'awaiting_change_approval'::character varying, 'completed'::character varying, 'paid'::character varying, 'cancelled'::character varying, 'rejected'::character varying, 'disputed'::character varying, 'refunded'::character varying]::text[])", name: "bookings_status_check"
  end

  create_table "cities", force: :cascade do |t|
    t.bigint "state_id", null: false
    t.string "slug", null: false
    t.jsonb "name_i18n", default: {}, null: false
    t.string "currency_code", limit: 3, null: false
    t.string "time_zone", null: false
    t.geography "center", limit: {srid: 4326, type: "st_point", geographic: true}, null: false
    t.integer "service_radius_m", default: 30000, null: false
    t.boolean "launched", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["center"], name: "index_cities_on_center", using: :gist
    t.index ["slug"], name: "index_cities_on_slug", unique: true
    t.index ["state_id"], name: "index_cities_on_state_id"
    t.check_constraint "service_radius_m >= 1000 AND service_radius_m <= 100000", name: "cities_service_radius_check"
  end

  create_table "commission_rules", force: :cascade do |t|
    t.bigint "city_id"
    t.bigint "service_category_id"
    t.integer "percent_bps", null: false
    t.bigint "fixed_minor", default: 0, null: false
    t.datetime "effective_from", null: false
    t.bigint "created_by_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["city_id", "service_category_id", "effective_from"], name: "index_commission_rules_uniqueness", unique: true, nulls_not_distinct: true
    t.index ["city_id"], name: "index_commission_rules_on_city_id"
    t.index ["created_by_id"], name: "index_commission_rules_on_created_by_id"
    t.index ["service_category_id"], name: "index_commission_rules_on_service_category_id"
    t.check_constraint "fixed_minor >= 0", name: "commission_rules_fixed_check"
    t.check_constraint "percent_bps >= 0 AND percent_bps <= 5000", name: "commission_rules_percent_check"
  end

  create_table "countries", force: :cascade do |t|
    t.string "iso2", limit: 2, null: false
    t.string "name", null: false
    t.string "currency_code", limit: 3, null: false
    t.string "phone_prefix", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["iso2"], name: "index_countries_on_iso2", unique: true
  end

  create_table "device_subscriptions", force: :cascade do |t|
    t.uuid "public_id", null: false
    t.bigint "user_id", null: false
    t.string "platform", default: "webpush", null: false
    t.string "app", null: false
    t.text "endpoint", null: false
    t.string "p256dh", null: false
    t.string "auth", null: false
    t.string "user_agent"
    t.datetime "last_seen_at"
    t.datetime "failed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["endpoint"], name: "index_device_subscriptions_on_endpoint", unique: true
    t.index ["public_id"], name: "index_device_subscriptions_on_public_id", unique: true
    t.index ["user_id"], name: "index_device_subscriptions_on_user_id"
    t.check_constraint "app::text = ANY (ARRAY['customer'::character varying, 'worker'::character varying]::text[])", name: "device_subscriptions_app_check"
    t.check_constraint "platform::text = 'webpush'::text", name: "device_subscriptions_platform_check"
  end

  create_table "disputes", force: :cascade do |t|
    t.uuid "public_id", null: false
    t.bigint "booking_id", null: false
    t.bigint "raised_by_id", null: false
    t.string "category", null: false
    t.text "description", null: false
    t.string "status", default: "open", null: false
    t.text "resolution"
    t.bigint "resolved_by_id"
    t.datetime "resolved_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["booking_id"], name: "index_disputes_one_open_per_booking", unique: true, where: "((status)::text = 'open'::text)"
    t.index ["public_id"], name: "index_disputes_on_public_id", unique: true
    t.index ["raised_by_id"], name: "index_disputes_on_raised_by_id"
    t.index ["resolved_by_id"], name: "index_disputes_on_resolved_by_id"
    t.index ["status", "created_at"], name: "index_disputes_on_status_and_created_at"
    t.check_constraint "category::text = ANY (ARRAY['no_show'::character varying, 'quality'::character varying, 'overcharge'::character varying, 'damage'::character varying, 'behaviour'::character varying, 'other'::character varying]::text[])", name: "disputes_category_check"
    t.check_constraint "status::text <> 'resolved'::text OR resolved_at IS NOT NULL AND resolution IS NOT NULL", name: "disputes_resolved_check"
    t.check_constraint "status::text = ANY (ARRAY['open'::character varying, 'resolved'::character varying]::text[])", name: "disputes_status_check"
  end

  create_table "idempotency_keys", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "key", null: false
    t.string "request_fingerprint", null: false
    t.integer "response_status"
    t.jsonb "response_body"
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.index ["created_at"], name: "index_idempotency_keys_on_created_at"
    t.index ["user_id", "key"], name: "index_idempotency_keys_on_user_id_and_key", unique: true
  end

  create_table "invoice_sequences", force: :cascade do |t|
    t.string "series", null: false
    t.integer "last_number", default: 0, null: false
    t.index ["series"], name: "index_invoice_sequences_on_series", unique: true
  end

  create_table "invoices", force: :cascade do |t|
    t.uuid "public_id", null: false
    t.bigint "booking_id", null: false
    t.string "number", null: false
    t.datetime "issued_at", null: false
    t.string "currency_code", limit: 3, null: false
    t.bigint "subtotal_minor", null: false
    t.bigint "tax_minor", null: false
    t.bigint "total_minor", null: false
    t.jsonb "lines", default: [], null: false
    t.jsonb "parties", default: {}, null: false
    t.datetime "created_at", null: false
    t.index ["booking_id"], name: "index_invoices_on_booking_id", unique: true
    t.index ["number"], name: "index_invoices_on_number", unique: true
    t.index ["public_id"], name: "index_invoices_on_public_id", unique: true
  end

  create_table "ledger_accounts", force: :cascade do |t|
    t.string "owner_type"
    t.bigint "owner_id"
    t.string "kind", null: false
    t.string "currency_code", limit: 3, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["owner_type", "owner_id", "kind", "currency_code"], name: "index_ledger_accounts_uniqueness", unique: true, nulls_not_distinct: true
    t.check_constraint "(owner_type IS NULL) = (owner_id IS NULL)", name: "ledger_accounts_owner_check"
    t.check_constraint "kind::text = ANY (ARRAY['worker_payable'::character varying, 'platform_revenue'::character varying, 'gateway_clearing'::character varying, 'cash_commission_receivable'::character varying, 'tax_payable'::character varying, 'customer_refunds'::character varying]::text[])", name: "ledger_accounts_kind_check"
  end

  create_table "ledger_entries", force: :cascade do |t|
    t.bigint "ledger_transaction_id", null: false
    t.bigint "ledger_account_id", null: false
    t.string "direction", null: false
    t.bigint "amount_minor", null: false
    t.string "currency_code", limit: 3, null: false
    t.datetime "created_at", null: false
    t.index ["ledger_account_id", "created_at"], name: "index_ledger_entries_on_ledger_account_id_and_created_at"
    t.index ["ledger_transaction_id"], name: "index_ledger_entries_on_ledger_transaction_id"
    t.check_constraint "amount_minor > 0", name: "ledger_entries_amount_check"
    t.check_constraint "direction::text = ANY (ARRAY['debit'::character varying, 'credit'::character varying]::text[])", name: "ledger_entries_direction_check"
  end

  create_table "ledger_transactions", force: :cascade do |t|
    t.uuid "public_id", null: false
    t.string "kind", null: false
    t.string "idempotency_key", null: false
    t.string "source_type"
    t.bigint "source_id"
    t.string "description"
    t.datetime "posted_at", null: false
    t.datetime "created_at", null: false
    t.index ["idempotency_key"], name: "index_ledger_transactions_on_idempotency_key", unique: true
    t.index ["public_id"], name: "index_ledger_transactions_on_public_id", unique: true
    t.index ["source_type", "source_id"], name: "index_ledger_transactions_on_source_type_and_source_id"
  end

  create_table "messages", force: :cascade do |t|
    t.uuid "public_id", null: false
    t.bigint "booking_id", null: false
    t.bigint "sender_id", null: false
    t.string "sender_role", null: false
    t.text "body", null: false
    t.datetime "created_at", null: false
    t.index ["booking_id", "created_at"], name: "index_messages_on_booking_id_and_created_at"
    t.index ["public_id"], name: "index_messages_on_public_id", unique: true
    t.index ["sender_id"], name: "index_messages_on_sender_id"
    t.check_constraint "char_length(body) >= 1 AND char_length(body) <= 2000", name: "messages_body_check"
    t.check_constraint "sender_role::text = ANY (ARRAY['customer'::character varying, 'worker'::character varying]::text[])", name: "messages_sender_role_check"
  end

  create_table "notifications", force: :cascade do |t|
    t.uuid "public_id", null: false
    t.bigint "user_id", null: false
    t.string "kind", null: false
    t.string "title", null: false
    t.string "body"
    t.string "url"
    t.jsonb "data", default: {}, null: false
    t.string "channels", default: [], null: false, array: true
    t.datetime "read_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["public_id"], name: "index_notifications_on_public_id", unique: true
    t.index ["user_id", "created_at"], name: "index_notifications_on_user_id_and_created_at"
    t.index ["user_id"], name: "index_notifications_unread", where: "(read_at IS NULL)"
  end

  create_table "otp_challenges", force: :cascade do |t|
    t.string "phone_e164", null: false
    t.string "code_digest", null: false
    t.integer "attempts", default: 0, null: false
    t.datetime "expires_at", null: false
    t.datetime "consumed_at"
    t.datetime "invalidated_at"
    t.inet "ip"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.index ["phone_e164", "created_at"], name: "index_otp_challenges_on_phone_e164_and_created_at"
    t.check_constraint "attempts >= 0", name: "otp_challenges_attempts_check"
  end

  create_table "payment_events", force: :cascade do |t|
    t.string "provider", null: false
    t.string "provider_event_id", null: false
    t.string "event_type", null: false
    t.jsonb "payload", null: false
    t.boolean "signature_valid", null: false
    t.datetime "processed_at"
    t.string "error"
    t.datetime "created_at", null: false
    t.index ["processed_at", "created_at"], name: "index_payment_events_on_processed_at_and_created_at"
    t.index ["provider", "provider_event_id"], name: "index_payment_events_on_provider_and_provider_event_id", unique: true
  end

  create_table "payments", force: :cascade do |t|
    t.uuid "public_id", null: false
    t.bigint "booking_id", null: false
    t.string "method", null: false
    t.string "provider", null: false
    t.string "provider_order_id"
    t.string "provider_payment_id"
    t.bigint "amount_minor", null: false
    t.string "currency_code", limit: 3, null: false
    t.string "status", default: "created", null: false
    t.bigint "refunded_minor", default: 0, null: false
    t.bigint "commission_minor"
    t.bigint "tax_minor"
    t.bigint "worker_share_minor"
    t.string "idempotency_key", null: false
    t.bigint "recorded_by_id"
    t.datetime "captured_at"
    t.datetime "failed_at"
    t.string "failure_reason"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["booking_id"], name: "index_payments_on_booking_id"
    t.index ["idempotency_key"], name: "index_payments_on_idempotency_key", unique: true
    t.index ["provider_order_id"], name: "index_payments_on_provider_order_id", unique: true
    t.index ["provider_payment_id"], name: "index_payments_on_provider_payment_id", unique: true
    t.index ["public_id"], name: "index_payments_on_public_id", unique: true
    t.index ["recorded_by_id"], name: "index_payments_on_recorded_by_id"
    t.check_constraint "amount_minor > 0 AND refunded_minor >= 0 AND refunded_minor <= amount_minor", name: "payments_amounts_check"
    t.check_constraint "method::text = ANY (ARRAY['online'::character varying, 'cash'::character varying]::text[])", name: "payments_method_check"
    t.check_constraint "status::text = ANY (ARRAY['created'::character varying, 'captured'::character varying, 'failed'::character varying, 'refunded'::character varying, 'partially_refunded'::character varying, 'amount_mismatch'::character varying]::text[])", name: "payments_status_check"
  end

  create_table "quotation_items", force: :cascade do |t|
    t.bigint "quotation_revision_id", null: false
    t.integer "position", null: false
    t.string "item_type", null: false
    t.string "description", null: false
    t.string "brand"
    t.decimal "quantity", precision: 10, scale: 3, null: false
    t.string "unit", null: false
    t.bigint "unit_price_minor", null: false
    t.string "condition"
    t.integer "warranty_days"
    t.bigint "amount_minor", null: false
    t.index ["quotation_revision_id", "position"], name: "index_quotation_items_on_quotation_revision_id_and_position", unique: true
    t.index ["quotation_revision_id"], name: "index_quotation_items_on_quotation_revision_id"
    t.check_constraint "condition IS NULL OR (condition::text = ANY (ARRAY['new'::character varying, 'refurbished'::character varying, 'used'::character varying]::text[]))", name: "quotation_items_condition_check"
    t.check_constraint "item_type::text = ANY (ARRAY['labour'::character varying, 'material'::character varying, 'transport'::character varying, 'inspection'::character varying, 'other'::character varying]::text[])", name: "quotation_items_type_check"
    t.check_constraint "quantity > 0::numeric", name: "quotation_items_quantity_check"
    t.check_constraint "unit_price_minor >= 0 AND amount_minor >= 0", name: "quotation_items_price_check"
    t.check_constraint "warranty_days IS NULL OR warranty_days >= 0 AND warranty_days <= 3650", name: "quotation_items_warranty_check"
  end

  create_table "quotation_revisions", force: :cascade do |t|
    t.uuid "public_id", null: false
    t.bigint "quotation_id", null: false
    t.integer "version", null: false
    t.string "stage", null: false
    t.bigint "subtotal_minor", null: false
    t.integer "tax_rate_bps", default: 0, null: false
    t.bigint "tax_minor", default: 0, null: false
    t.bigint "total_minor", null: false
    t.string "currency_code", limit: 3, null: false
    t.text "notes"
    t.integer "estimated_minutes"
    t.bigint "created_by_id", null: false
    t.datetime "created_at", null: false
    t.index ["created_by_id"], name: "index_quotation_revisions_on_created_by_id"
    t.index ["public_id"], name: "index_quotation_revisions_on_public_id", unique: true
    t.index ["quotation_id", "version"], name: "index_quotation_revisions_on_quotation_id_and_version", unique: true
    t.check_constraint "estimated_minutes IS NULL OR estimated_minutes >= 1 AND estimated_minutes <= 20160", name: "quotation_revisions_estimate_check"
    t.check_constraint "stage::text = ANY (ARRAY['initial'::character varying, 'inspection_fee'::character varying, 'final'::character varying, 'change_order'::character varying]::text[])", name: "quotation_revisions_stage_check"
    t.check_constraint "subtotal_minor >= 0 AND tax_minor >= 0 AND total_minor = (subtotal_minor + tax_minor)", name: "quotation_revisions_totals_check"
    t.check_constraint "tax_rate_bps >= 0 AND tax_rate_bps <= 5000", name: "quotation_revisions_tax_rate_check"
    t.check_constraint "version > 0", name: "quotation_revisions_version_check"
  end

  create_table "quotations", force: :cascade do |t|
    t.uuid "public_id", null: false
    t.bigint "service_request_id", null: false
    t.bigint "worker_profile_id", null: false
    t.bigint "request_invitation_id", null: false
    t.string "kind", null: false
    t.string "status", default: "submitted", null: false
    t.integer "current_version", default: 1, null: false
    t.datetime "valid_until", null: false
    t.datetime "accepted_at"
    t.datetime "declined_at"
    t.string "decline_reason"
    t.datetime "withdrawn_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["public_id"], name: "index_quotations_on_public_id", unique: true
    t.index ["request_invitation_id"], name: "index_quotations_on_request_invitation_id", unique: true
    t.index ["service_request_id", "worker_profile_id"], name: "index_quotations_on_service_request_id_and_worker_profile_id", unique: true
    t.index ["service_request_id"], name: "index_quotations_one_accepted_per_request", unique: true, where: "((status)::text = 'accepted'::text)"
    t.index ["worker_profile_id", "created_at"], name: "index_quotations_on_worker_profile_id_and_created_at"
    t.check_constraint "current_version > 0", name: "quotations_version_check"
    t.check_constraint "kind::text = ANY (ARRAY['fixed'::character varying, 'inspection'::character varying]::text[])", name: "quotations_kind_check"
    t.check_constraint "status::text <> 'accepted'::text OR accepted_at IS NOT NULL", name: "quotations_accepted_check"
    t.check_constraint "status::text = ANY (ARRAY['submitted'::character varying, 'accepted'::character varying, 'declined'::character varying, 'withdrawn'::character varying, 'expired'::character varying]::text[])", name: "quotations_status_check"
  end

  create_table "refresh_tokens", force: :cascade do |t|
    t.bigint "user_session_id", null: false
    t.string "token_digest", null: false
    t.datetime "expires_at", null: false
    t.datetime "rotated_at"
    t.datetime "created_at", null: false
    t.index ["token_digest"], name: "index_refresh_tokens_on_token_digest", unique: true
    t.index ["user_session_id"], name: "index_refresh_tokens_on_user_session_id"
  end

  create_table "refunds", force: :cascade do |t|
    t.uuid "public_id", null: false
    t.bigint "payment_id", null: false
    t.bigint "amount_minor", null: false
    t.string "reason", null: false
    t.string "status", default: "pending", null: false
    t.string "provider_refund_id"
    t.bigint "initiated_by_id", null: false
    t.datetime "processed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["initiated_by_id"], name: "index_refunds_on_initiated_by_id"
    t.index ["payment_id"], name: "index_refunds_on_payment_id"
    t.index ["provider_refund_id"], name: "index_refunds_on_provider_refund_id", unique: true
    t.index ["public_id"], name: "index_refunds_on_public_id", unique: true
    t.check_constraint "amount_minor > 0", name: "refunds_amount_check"
    t.check_constraint "status::text = ANY (ARRAY['pending'::character varying, 'processed'::character varying, 'failed'::character varying]::text[])", name: "refunds_status_check"
  end

  create_table "request_attachments", force: :cascade do |t|
    t.uuid "public_id", null: false
    t.bigint "service_request_id", null: false
    t.string "kind", default: "image", null: false
    t.integer "width"
    t.integer "height"
    t.text "transcript"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["public_id"], name: "index_request_attachments_on_public_id", unique: true
    t.index ["service_request_id"], name: "index_request_attachments_on_service_request_id"
    t.check_constraint "kind::text = ANY (ARRAY['image'::character varying, 'audio'::character varying, 'video'::character varying]::text[])", name: "request_attachments_kind_check"
  end

  create_table "request_invitations", force: :cascade do |t|
    t.uuid "public_id", null: false
    t.bigint "service_request_id", null: false
    t.bigint "worker_profile_id", null: false
    t.integer "rank", null: false
    t.decimal "rank_score", precision: 6, scale: 4, null: false
    t.integer "distance_m", null: false
    t.datetime "notified_at"
    t.string "notified_via"
    t.datetime "viewed_at"
    t.datetime "declined_at"
    t.string "decline_reason"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["public_id"], name: "index_request_invitations_on_public_id", unique: true
    t.index ["service_request_id", "worker_profile_id"], name: "idx_on_service_request_id_worker_profile_id_1b4062c7a1", unique: true
    t.index ["worker_profile_id", "created_at"], name: "index_request_invitations_on_worker_profile_id_and_created_at"
    t.check_constraint "distance_m >= 0", name: "request_invitations_distance_check"
    t.check_constraint "notified_via IS NULL OR (notified_via::text = ANY (ARRAY['push'::character varying, 'sms'::character varying, 'none'::character varying]::text[]))", name: "request_invitations_notified_via_check"
    t.check_constraint "rank > 0", name: "request_invitations_rank_check"
  end

  create_table "reviews", force: :cascade do |t|
    t.uuid "public_id", null: false
    t.bigint "booking_id", null: false
    t.bigint "reviewer_id", null: false
    t.bigint "worker_profile_id", null: false
    t.integer "rating", null: false
    t.text "body"
    t.datetime "created_at", null: false
    t.index ["booking_id"], name: "index_reviews_on_booking_id", unique: true
    t.index ["public_id"], name: "index_reviews_on_public_id", unique: true
    t.index ["reviewer_id"], name: "index_reviews_on_reviewer_id"
    t.index ["worker_profile_id", "created_at"], name: "index_reviews_on_worker_profile_id_and_created_at"
    t.check_constraint "rating >= 1 AND rating <= 5", name: "reviews_rating_check"
  end

  create_table "service_categories", force: :cascade do |t|
    t.bigint "parent_id"
    t.string "slug", null: false
    t.jsonb "name_i18n", default: {}, null: false
    t.jsonb "description_i18n", default: {}, null: false
    t.string "icon"
    t.boolean "inspection_allowed", default: true, null: false
    t.boolean "active", default: true, null: false
    t.integer "sort", default: 0, null: false
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "tax_rate_bps", default: 0, null: false
    t.index ["parent_id"], name: "index_service_categories_on_parent_id"
    t.index ["slug"], name: "index_service_categories_on_slug", unique: true
    t.check_constraint "name_i18n ? 'en'::text", name: "service_categories_name_en_check"
    t.check_constraint "parent_id IS NULL OR parent_id <> id", name: "service_categories_parent_check"
    t.check_constraint "tax_rate_bps >= 0 AND tax_rate_bps <= 5000", name: "service_categories_tax_rate_check"
  end

  create_table "service_requests", force: :cascade do |t|
    t.uuid "public_id", null: false
    t.bigint "customer_id", null: false
    t.bigint "service_category_id"
    t.bigint "address_id"
    t.text "description"
    t.jsonb "answers", default: [], null: false
    t.bigint "triage_analysis_id"
    t.text "ai_summary"
    t.string "category_source"
    t.boolean "safety_flag", default: false, null: false
    t.string "urgency", default: "flexible", null: false
    t.datetime "preferred_from"
    t.datetime "preferred_to"
    t.bigint "city_id"
    t.geography "location", limit: {srid: 4326, type: "st_point", geographic: true}
    t.jsonb "address_snapshot"
    t.string "status", default: "draft", null: false
    t.datetime "submitted_at"
    t.datetime "expires_at"
    t.datetime "cancelled_at"
    t.string "cancel_reason"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "matched_at"
    t.integer "invited_count", default: 0, null: false
    t.index ["address_id"], name: "index_service_requests_on_address_id"
    t.index ["customer_id", "created_at"], name: "index_service_requests_on_customer_id_and_created_at"
    t.index ["location"], name: "index_service_requests_on_location", using: :gist
    t.index ["public_id"], name: "index_service_requests_on_public_id", unique: true
    t.index ["status", "expires_at"], name: "index_service_requests_on_status_and_expires_at"
    t.index ["status", "service_category_id"], name: "index_service_requests_on_status_and_service_category_id"
    t.check_constraint "category_source IS NULL OR (category_source::text = ANY (ARRAY['ai'::character varying, 'customer'::character varying]::text[]))", name: "service_requests_category_source_check"
    t.check_constraint "preferred_from IS NULL OR preferred_to IS NULL OR preferred_to > preferred_from", name: "service_requests_window_check"
    t.check_constraint "status::text <> 'cancelled'::text OR cancelled_at IS NOT NULL", name: "service_requests_cancelled_check"
    t.check_constraint "status::text = 'draft'::text OR service_category_id IS NOT NULL AND address_id IS NOT NULL AND city_id IS NOT NULL AND location IS NOT NULL AND address_snapshot IS NOT NULL AND submitted_at IS NOT NULL AND expires_at IS NOT NULL", name: "service_requests_submitted_complete_check"
    t.check_constraint "status::text = ANY (ARRAY['draft'::character varying, 'open'::character varying, 'quoting'::character varying, 'booked'::character varying, 'fulfilled'::character varying, 'expired'::character varying, 'cancelled'::character varying]::text[])", name: "service_requests_status_check"
    t.check_constraint "urgency::text = ANY (ARRAY['asap'::character varying, 'today'::character varying, 'this_week'::character varying, 'flexible'::character varying]::text[])", name: "service_requests_urgency_check"
  end

  create_table "states", force: :cascade do |t|
    t.bigint "country_id", null: false
    t.string "code", null: false
    t.string "name", null: false
    t.string "kind", default: "state", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["country_id", "code"], name: "index_states_on_country_id_and_code", unique: true
    t.check_constraint "kind::text = ANY (ARRAY['state'::character varying, 'union_territory'::character varying]::text[])", name: "states_kind_check"
  end

  create_table "user_roles", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "role", null: false
    t.bigint "granted_by_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["granted_by_id"], name: "index_user_roles_on_granted_by_id"
    t.index ["user_id", "role"], name: "index_user_roles_on_user_id_and_role", unique: true
    t.check_constraint "role::text = ANY (ARRAY['customer'::character varying, 'worker'::character varying, 'admin'::character varying, 'support'::character varying, 'finance'::character varying, 'verifier'::character varying]::text[])", name: "user_roles_role_check"
  end

  create_table "user_sessions", force: :cascade do |t|
    t.uuid "public_id", null: false
    t.bigint "user_id", null: false
    t.string "scope", null: false
    t.datetime "mfa_verified_at"
    t.datetime "expires_at", null: false
    t.datetime "revoked_at"
    t.string "revoke_reason"
    t.inet "ip"
    t.string "user_agent"
    t.datetime "last_seen_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["public_id"], name: "index_user_sessions_on_public_id", unique: true
    t.index ["user_id"], name: "index_user_sessions_on_user_id"
    t.check_constraint "scope::text <> 'staff'::text OR mfa_verified_at IS NOT NULL", name: "user_sessions_staff_mfa_check"
    t.check_constraint "scope::text = ANY (ARRAY['consumer'::character varying, 'staff'::character varying]::text[])", name: "user_sessions_scope_check"
  end

  create_table "users", force: :cascade do |t|
    t.uuid "public_id", null: false
    t.string "phone_e164", null: false
    t.string "name"
    t.citext "email"
    t.string "locale", default: "en", null: false
    t.string "status", default: "active", null: false
    t.text "totp_secret"
    t.datetime "totp_enabled_at"
    t.bigint "totp_last_step"
    t.datetime "last_login_at"
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true, where: "((deleted_at IS NULL) AND (email IS NOT NULL))"
    t.index ["phone_e164"], name: "index_users_on_phone_e164", unique: true, where: "(deleted_at IS NULL)"
    t.index ["public_id"], name: "index_users_on_public_id", unique: true
    t.check_constraint "locale::text = ANY (ARRAY['en'::character varying, 'hi'::character varying, 'pa'::character varying]::text[])", name: "users_locale_check"
    t.check_constraint "phone_e164::text ~ '^\\+[1-9][0-9]{7,14}$'::text", name: "users_phone_e164_check"
    t.check_constraint "status::text = ANY (ARRAY['active'::character varying, 'suspended'::character varying]::text[])", name: "users_status_check"
  end

  create_table "worker_documents", force: :cascade do |t|
    t.uuid "public_id", null: false
    t.bigint "worker_profile_id", null: false
    t.string "kind", null: false
    t.string "doc_type", null: false
    t.string "number_last4"
    t.string "status", default: "pending", null: false
    t.bigint "reviewed_by_id"
    t.datetime "reviewed_at"
    t.string "rejection_reason"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["public_id"], name: "index_worker_documents_on_public_id", unique: true
    t.index ["reviewed_by_id"], name: "index_worker_documents_on_reviewed_by_id"
    t.index ["worker_profile_id", "kind"], name: "index_worker_documents_one_live_per_kind", unique: true, where: "((status)::text = ANY ((ARRAY['pending'::character varying, 'approved'::character varying])::text[]))"
    t.index ["worker_profile_id"], name: "index_worker_documents_on_worker_profile_id"
    t.check_constraint "kind::text = ANY (ARRAY['identity'::character varying, 'address'::character varying, 'trade'::character varying]::text[])", name: "worker_documents_kind_check"
    t.check_constraint "number_last4 IS NULL OR number_last4::text ~ '^[A-Za-z0-9]{4}$'::text", name: "worker_documents_last4_check"
    t.check_constraint "status::text = ANY (ARRAY['pending'::character varying, 'approved'::character varying, 'rejected'::character varying, 'superseded'::character varying]::text[])", name: "worker_documents_status_check"
  end

  create_table "worker_payouts", force: :cascade do |t|
    t.uuid "public_id", null: false
    t.bigint "worker_profile_id", null: false
    t.bigint "amount_minor", null: false
    t.string "currency_code", limit: 3, null: false
    t.string "status", default: "paid", null: false
    t.string "provider_ref", null: false
    t.bigint "created_by_id", null: false
    t.bigint "ledger_transaction_id"
    t.datetime "paid_at", null: false
    t.datetime "created_at", null: false
    t.index ["created_by_id"], name: "index_worker_payouts_on_created_by_id"
    t.index ["ledger_transaction_id"], name: "index_worker_payouts_on_ledger_transaction_id"
    t.index ["public_id"], name: "index_worker_payouts_on_public_id", unique: true
    t.index ["worker_profile_id"], name: "index_worker_payouts_on_worker_profile_id"
    t.check_constraint "amount_minor > 0", name: "worker_payouts_amount_check"
    t.check_constraint "status::text = 'paid'::text", name: "worker_payouts_status_check"
  end

  create_table "worker_profiles", force: :cascade do |t|
    t.uuid "public_id", null: false
    t.bigint "user_id", null: false
    t.text "bio"
    t.integer "experience_years"
    t.string "verification_status", default: "draft", null: false
    t.boolean "available", default: false, null: false
    t.decimal "rating_avg", precision: 3, scale: 2
    t.integer "rating_count", default: 0, null: false
    t.datetime "submitted_at"
    t.datetime "approved_at"
    t.datetime "suspended_at"
    t.string "suspension_reason"
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["public_id"], name: "index_worker_profiles_on_public_id", unique: true
    t.index ["user_id"], name: "index_worker_profiles_on_user_id", unique: true
    t.index ["verification_status", "available"], name: "index_worker_profiles_on_verification_status_and_available"
    t.index ["verification_status", "submitted_at"], name: "index_worker_profiles_on_verification_status_and_submitted_at"
    t.check_constraint "NOT available OR verification_status::text = 'approved'::text AND suspended_at IS NULL", name: "worker_profiles_available_check"
    t.check_constraint "experience_years IS NULL OR experience_years >= 0 AND experience_years <= 60", name: "worker_profiles_experience_check"
    t.check_constraint "verification_status::text = ANY (ARRAY['draft'::character varying, 'pending_review'::character varying, 'changes_requested'::character varying, 'approved'::character varying, 'rejected'::character varying]::text[])", name: "worker_profiles_verification_status_check"
  end

  create_table "worker_service_areas", force: :cascade do |t|
    t.uuid "public_id", null: false
    t.bigint "worker_profile_id", null: false
    t.bigint "city_id", null: false
    t.string "label"
    t.geography "center", limit: {srid: 4326, type: "st_point", geographic: true}, null: false
    t.integer "radius_m", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["center"], name: "index_worker_service_areas_on_center", using: :gist
    t.index ["city_id"], name: "index_worker_service_areas_on_city_id"
    t.index ["public_id"], name: "index_worker_service_areas_on_public_id", unique: true
    t.index ["worker_profile_id"], name: "index_worker_service_areas_on_worker_profile_id"
    t.check_constraint "radius_m >= 500 AND radius_m <= 50000", name: "worker_service_areas_radius_check"
  end

  create_table "worker_skills", force: :cascade do |t|
    t.bigint "worker_profile_id", null: false
    t.bigint "service_category_id", null: false
    t.integer "experience_years"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["service_category_id"], name: "index_worker_skills_on_service_category_id"
    t.index ["worker_profile_id", "service_category_id"], name: "idx_on_worker_profile_id_service_category_id_974a38beba", unique: true
    t.check_constraint "experience_years IS NULL OR experience_years >= 0 AND experience_years <= 60", name: "worker_skills_experience_check"
  end

  create_table "worker_verifications", force: :cascade do |t|
    t.bigint "worker_profile_id", null: false
    t.bigint "admin_id", null: false
    t.string "decision", null: false
    t.text "reason"
    t.jsonb "document_decisions", default: [], null: false
    t.datetime "created_at", null: false
    t.index ["admin_id"], name: "index_worker_verifications_on_admin_id"
    t.index ["worker_profile_id"], name: "index_worker_verifications_on_worker_profile_id"
    t.check_constraint "decision::text = ANY (ARRAY['approved'::character varying, 'changes_requested'::character varying, 'rejected'::character varying, 'suspended'::character varying, 'reinstated'::character varying]::text[])", name: "worker_verifications_decision_check"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "addresses", "cities"
  add_foreign_key "addresses", "users"
  add_foreign_key "admin_actions", "users", column: "admin_id"
  add_foreign_key "ai_analyses", "service_categories", column: "suggested_category_id"
  add_foreign_key "ai_analyses", "users"
  add_foreign_key "booking_approvals", "bookings"
  add_foreign_key "booking_approvals", "quotation_revisions"
  add_foreign_key "booking_approvals", "users", column: "decided_by_id"
  add_foreign_key "booking_status_histories", "bookings"
  add_foreign_key "booking_status_histories", "users", column: "actor_id"
  add_foreign_key "bookings", "quotation_revisions", column: "pending_revision_id"
  add_foreign_key "bookings", "quotations"
  add_foreign_key "bookings", "service_requests"
  add_foreign_key "bookings", "users", column: "customer_id"
  add_foreign_key "bookings", "worker_profiles"
  add_foreign_key "cities", "states"
  add_foreign_key "commission_rules", "cities"
  add_foreign_key "commission_rules", "service_categories"
  add_foreign_key "commission_rules", "users", column: "created_by_id"
  add_foreign_key "device_subscriptions", "users"
  add_foreign_key "disputes", "bookings"
  add_foreign_key "disputes", "users", column: "raised_by_id"
  add_foreign_key "disputes", "users", column: "resolved_by_id"
  add_foreign_key "idempotency_keys", "users"
  add_foreign_key "invoices", "bookings"
  add_foreign_key "ledger_entries", "ledger_accounts"
  add_foreign_key "ledger_entries", "ledger_transactions"
  add_foreign_key "messages", "bookings"
  add_foreign_key "messages", "users", column: "sender_id"
  add_foreign_key "notifications", "users"
  add_foreign_key "payments", "bookings"
  add_foreign_key "payments", "users", column: "recorded_by_id"
  add_foreign_key "quotation_items", "quotation_revisions"
  add_foreign_key "quotation_revisions", "quotations"
  add_foreign_key "quotation_revisions", "users", column: "created_by_id"
  add_foreign_key "quotations", "request_invitations"
  add_foreign_key "quotations", "service_requests"
  add_foreign_key "quotations", "worker_profiles"
  add_foreign_key "refresh_tokens", "user_sessions"
  add_foreign_key "refunds", "payments"
  add_foreign_key "refunds", "users", column: "initiated_by_id"
  add_foreign_key "request_attachments", "service_requests"
  add_foreign_key "request_invitations", "service_requests"
  add_foreign_key "request_invitations", "worker_profiles"
  add_foreign_key "reviews", "bookings"
  add_foreign_key "reviews", "users", column: "reviewer_id"
  add_foreign_key "reviews", "worker_profiles"
  add_foreign_key "service_categories", "service_categories", column: "parent_id"
  add_foreign_key "service_requests", "addresses"
  add_foreign_key "service_requests", "ai_analyses", column: "triage_analysis_id"
  add_foreign_key "service_requests", "cities"
  add_foreign_key "service_requests", "service_categories"
  add_foreign_key "service_requests", "users", column: "customer_id"
  add_foreign_key "states", "countries"
  add_foreign_key "user_roles", "users"
  add_foreign_key "user_roles", "users", column: "granted_by_id"
  add_foreign_key "user_sessions", "users"
  add_foreign_key "worker_documents", "users", column: "reviewed_by_id"
  add_foreign_key "worker_documents", "worker_profiles"
  add_foreign_key "worker_payouts", "ledger_transactions"
  add_foreign_key "worker_payouts", "users", column: "created_by_id"
  add_foreign_key "worker_payouts", "worker_profiles"
  add_foreign_key "worker_profiles", "users"
  add_foreign_key "worker_service_areas", "cities"
  add_foreign_key "worker_service_areas", "worker_profiles"
  add_foreign_key "worker_skills", "service_categories"
  add_foreign_key "worker_skills", "worker_profiles"
  add_foreign_key "worker_verifications", "users", column: "admin_id"
  add_foreign_key "worker_verifications", "worker_profiles"
end
