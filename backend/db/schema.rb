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

ActiveRecord::Schema[8.1].define(version: 2026_10_30_110400) do
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
  add_foreign_key "admin_actions", "users", column: "admin_id"
  add_foreign_key "cities", "states"
  add_foreign_key "refresh_tokens", "user_sessions"
  add_foreign_key "service_categories", "service_categories", column: "parent_id"
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
