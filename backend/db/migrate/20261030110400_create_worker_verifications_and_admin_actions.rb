class CreateWorkerVerificationsAndAdminActions < ActiveRecord::Migration[8.1]
  def change
    # Append-only review history (models are read-only once saved).
    create_table :worker_verifications do |t|
      t.references :worker_profile, null: false, foreign_key: true
      t.references :admin, null: false, foreign_key: { to_table: :users }
      t.string :decision, null: false
      t.text :reason
      t.jsonb :document_decisions, null: false, default: []
      t.datetime :created_at, null: false
    end
    add_check_constraint :worker_verifications,
      "decision IN ('approved','changes_requested','rejected','suspended','reinstated')",
      name: "worker_verifications_decision_check"

    # Append-only audit log of every staff mutation.
    create_table :admin_actions do |t|
      t.references :admin, null: false, foreign_key: { to_table: :users }
      t.string :admin_role, null: false
      t.string :action, null: false
      t.string :target_type, null: false
      t.bigint :target_id, null: false
      t.jsonb :changes_made, null: false, default: {}
      t.text :reason
      t.inet :ip
      t.string :user_agent
      t.string :request_id
      t.datetime :created_at, null: false
    end
    add_index :admin_actions, %i[target_type target_id]
    add_index :admin_actions, :created_at
  end
end
