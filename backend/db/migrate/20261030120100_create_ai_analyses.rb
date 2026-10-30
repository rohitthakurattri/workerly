class CreateAiAnalyses < ActiveRecord::Migration[8.1]
  def change
    # One row per AI call (or cache hit). Append-only: the record of what the model was asked and said.
    create_table :ai_analyses do |t|
      t.uuid :public_id, null: false
      t.references :analysable, polymorphic: true, null: false
      t.references :user, foreign_key: true, index: false    # who triggered it (budgets)
      t.string :use_case, null: false                        # triage (Phase 3); transcribe, image, summary later
      t.string :provider, null: false
      t.string :model
      t.string :prompt_version, null: false
      t.string :input_hash, null: false
      t.string :status, null: false
      t.boolean :cached, null: false, default: false
      t.jsonb :output
      t.references :suggested_category, foreign_key: { to_table: :service_categories }, index: false
      t.decimal :confidence, precision: 4, scale: 3
      t.integer :input_tokens
      t.integer :output_tokens
      t.bigint :cost_micros                                  # millionths of currency_code
      t.string :currency_code, limit: 3
      t.integer :latency_ms
      t.string :error_code
      t.datetime :created_at, null: false
    end
    add_index :ai_analyses, :public_id, unique: true
    add_index :ai_analyses, %i[use_case input_hash created_at]
    add_index :ai_analyses, %i[user_id use_case created_at]
    add_index :ai_analyses, %i[provider status created_at]
    add_check_constraint :ai_analyses, "status IN ('succeeded','failed')", name: "ai_analyses_status_check"
    add_check_constraint :ai_analyses, "confidence IS NULL OR confidence BETWEEN 0 AND 1", name: "ai_analyses_confidence_check"
  end
end
