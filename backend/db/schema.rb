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

ActiveRecord::Schema[8.1].define(version: 2026_10_30_100500) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "citext"
  enable_extension "pg_catalog.plpgsql"
  enable_extension "postgis"

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

  add_foreign_key "refresh_tokens", "user_sessions"
  add_foreign_key "user_roles", "users"
  add_foreign_key "user_roles", "users", column: "granted_by_id"
  add_foreign_key "user_sessions", "users"
end
