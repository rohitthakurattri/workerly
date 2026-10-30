class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.uuid :public_id, null: false
      t.string :phone_e164, null: false
      t.string :name
      t.citext :email
      t.string :locale, null: false, default: "en"
      t.string :status, null: false, default: "active"
      t.text :totp_secret                 # Active Record encrypted; staff only
      t.datetime :totp_enabled_at
      t.bigint :totp_last_step            # last accepted TOTP time step, blocks replay
      t.datetime :last_login_at
      t.datetime :deleted_at
      t.timestamps
    end

    add_index :users, :public_id, unique: true
    add_index :users, :phone_e164, unique: true, where: "deleted_at IS NULL"
    add_index :users, :email, unique: true, where: "deleted_at IS NULL AND email IS NOT NULL"
    add_check_constraint :users, "status IN ('active','suspended')", name: "users_status_check"
    add_check_constraint :users, "locale IN ('en','hi','pa')", name: "users_locale_check"
    add_check_constraint :users, "phone_e164 ~ '^\\+[1-9][0-9]{7,14}$'", name: "users_phone_e164_check"
  end
end
