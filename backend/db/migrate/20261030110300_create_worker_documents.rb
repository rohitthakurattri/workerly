class CreateWorkerDocuments < ActiveRecord::Migration[8.1]
  def change
    create_table :worker_documents do |t|
      t.uuid :public_id, null: false
      t.references :worker_profile, null: false, foreign_key: true
      t.string :kind, null: false          # identity | address | trade
      t.string :doc_type, null: false      # aadhaar_masked | pan | voter_id | driving_licence | passport | utility_bill | rent_agreement | trade_certificate | other
      t.string :number_last4              # never the full number
      t.string :status, null: false, default: "pending"
      t.references :reviewed_by, foreign_key: { to_table: :users }
      t.datetime :reviewed_at
      t.string :rejection_reason
      t.timestamps
    end
    add_index :worker_documents, :public_id, unique: true
    # One live document per kind; rejected/superseded ones stay as history.
    add_index :worker_documents, %i[worker_profile_id kind], unique: true,
      where: "status IN ('pending','approved')", name: "index_worker_documents_one_live_per_kind"
    add_check_constraint :worker_documents, "kind IN ('identity','address','trade')", name: "worker_documents_kind_check"
    add_check_constraint :worker_documents, "status IN ('pending','approved','rejected','superseded')",
      name: "worker_documents_status_check"
    add_check_constraint :worker_documents, "number_last4 IS NULL OR number_last4 ~ '^[A-Za-z0-9]{4}$'",
      name: "worker_documents_last4_check"
  end
end
