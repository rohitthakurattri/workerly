class CreateUserSessions < ActiveRecord::Migration[8.1]
  def change
    create_table :user_sessions do |t|
      t.uuid :public_id, null: false
      t.references :user, null: false, foreign_key: true
      t.string :scope, null: false               # consumer | staff
      t.datetime :mfa_verified_at
      t.datetime :expires_at, null: false        # absolute cap; refresh cannot extend it
      t.datetime :revoked_at
      t.string :revoke_reason
      t.inet :ip
      t.string :user_agent
      t.datetime :last_seen_at
      t.timestamps
    end

    add_index :user_sessions, :public_id, unique: true
    add_check_constraint :user_sessions, "scope IN ('consumer','staff')", name: "user_sessions_scope_check"
    add_check_constraint :user_sessions, "scope <> 'staff' OR mfa_verified_at IS NOT NULL",
      name: "user_sessions_staff_mfa_check"
  end
end
