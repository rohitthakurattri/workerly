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

ActiveRecord::Schema[8.1].define(version: 2026_10_30_120200) do
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

  create_table "countries", force: :cascade do |t|
    t.string "iso2", limit: 2, null: false
    t.string "name", null: false
    t.string "currency_code", limit: 3, null: false
    t.string "phone_prefix", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["iso2"], name: "index_countries_on_iso2", unique: true
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

  create_table "refresh_tokens", force: :cascade do |t|
    t.bigint "user_session_id", null: false
    t.string "token_digest", null: false
    t.datetime "expires_at", null: false
    t.datetime "rotated_at"
    t.datetime "created_at", null: false
    t.index ["token_digest"], name: "index_refresh_tokens_on_token_digest", unique: true
    t.index ["user_session_id"], name: "index_refresh_tokens_on_user_session_id"
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
    t.index ["parent_id"], name: "index_service_categories_on_parent_id"
    t.index ["slug"], name: "index_service_categories_on_slug", unique: true
    t.check_constraint "name_i18n ? 'en'::text", name: "service_categories_name_en_check"
    t.check_constraint "parent_id IS NULL OR parent_id <> id", name: "service_categories_parent_check"
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
    t.check_constraint "kind::text = ANY (ARRAY['state'::character varying::text, 'union_territory'::character varying::text])", name: "states_kind_check"
  end

  create_table "user_roles", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "role", null: false
    t.bigint "granted_by_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["granted_by_id"], name: "index_user_roles_on_granted_by_id"
    t.index ["user_id", "role"], name: "index_user_roles_on_user_id_and_role", unique: true
    t.check_constraint "role::text = ANY (ARRAY['customer'::character varying::text, 'worker'::character varying::text, 'admin'::character varying::text, 'support'::character varying::text, 'finance'::character varying::text, 'verifier'::character varying::text])", name: "user_roles_role_check"
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
    t.check_constraint "scope::text = ANY (ARRAY['consumer'::character varying::text, 'staff'::character varying::text])", name: "user_sessions_scope_check"
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
    t.check_constraint "locale::text = ANY (ARRAY['en'::character varying::text, 'hi'::character varying::text, 'pa'::character varying::text])", name: "users_locale_check"
    t.check_constraint "phone_e164::text ~ '^\\+[1-9][0-9]{7,14}$'::text", name: "users_phone_e164_check"
    t.check_constraint "status::text = ANY (ARRAY['active'::character varying::text, 'suspended'::character varying::text])", name: "users_status_check"
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
    t.index ["worker_profile_id", "kind"], name: "index_worker_documents_one_live_per_kind", unique: true, where: "((status)::text = ANY (ARRAY[('pending'::character varying)::text, ('approved'::character varying)::text]))"
    t.index ["worker_profile_id"], name: "index_worker_documents_on_worker_profile_id"
    t.check_constraint "kind::text = ANY (ARRAY['identity'::character varying::text, 'address'::character varying::text, 'trade'::character varying::text])", name: "worker_documents_kind_check"
    t.check_constraint "number_last4 IS NULL OR number_last4::text ~ '^[A-Za-z0-9]{4}$'::text", name: "worker_documents_last4_check"
    t.check_constraint "status::text = ANY (ARRAY['pending'::character varying::text, 'approved'::character varying::text, 'rejected'::character varying::text, 'superseded'::character varying::text])", name: "worker_documents_status_check"
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
    t.check_constraint "verification_status::text = ANY (ARRAY['draft'::character varying::text, 'pending_review'::character varying::text, 'changes_requested'::character varying::text, 'approved'::character varying::text, 'rejected'::character varying::text])", name: "worker_profiles_verification_status_check"
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
    t.check_constraint "decision::text = ANY (ARRAY['approved'::character varying::text, 'changes_requested'::character varying::text, 'rejected'::character varying::text, 'suspended'::character varying::text, 'reinstated'::character varying::text])", name: "worker_verifications_decision_check"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "addresses", "cities"
  add_foreign_key "addresses", "users"
  add_foreign_key "admin_actions", "users", column: "admin_id"
  add_foreign_key "ai_analyses", "service_categories", column: "suggested_category_id"
  add_foreign_key "ai_analyses", "users"
  add_foreign_key "cities", "states"
  add_foreign_key "refresh_tokens", "user_sessions"
  add_foreign_key "request_attachments", "service_requests"
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
  add_foreign_key "worker_profiles", "users"
  add_foreign_key "worker_service_areas", "cities"
  add_foreign_key "worker_service_areas", "worker_profiles"
  add_foreign_key "worker_skills", "service_categories"
  add_foreign_key "worker_skills", "worker_profiles"
  add_foreign_key "worker_verifications", "users", column: "admin_id"
  add_foreign_key "worker_verifications", "worker_profiles"
end
