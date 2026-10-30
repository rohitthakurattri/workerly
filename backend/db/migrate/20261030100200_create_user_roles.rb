class CreateUserRoles < ActiveRecord::Migration[8.1]
  def change
    create_table :user_roles do |t|
      t.references :user, null: false, foreign_key: true, index: false
      t.string :role, null: false
      t.references :granted_by, foreign_key: { to_table: :users }
      t.timestamps
    end

    add_index :user_roles, %i[user_id role], unique: true
    add_check_constraint :user_roles,
      "role IN ('customer','worker','admin','support','finance','verifier')",
      name: "user_roles_role_check"
  end
end
