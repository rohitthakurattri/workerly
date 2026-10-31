class CreateIdempotencyKeys < ActiveRecord::Migration[8.1]
  def change
    # Acceptance and money endpoints take an Idempotency-Key header; a replay gets the stored response.
    create_table :idempotency_keys do |t|
      t.references :user, null: false, foreign_key: true, index: false
      t.string :key, null: false
      t.string :request_fingerprint, null: false         # method + path + body digest
      t.integer :response_status
      t.jsonb :response_body
      t.datetime :completed_at
      t.datetime :created_at, null: false
    end
    add_index :idempotency_keys, %i[user_id key], unique: true
    add_index :idempotency_keys, :created_at
  end
end
