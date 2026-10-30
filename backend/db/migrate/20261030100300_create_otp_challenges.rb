class CreateOtpChallenges < ActiveRecord::Migration[8.1]
  def change
    create_table :otp_challenges do |t|
      t.string :phone_e164, null: false
      t.string :code_digest, null: false
      t.integer :attempts, null: false, default: 0
      t.datetime :expires_at, null: false
      t.datetime :consumed_at
      t.datetime :invalidated_at
      t.inet :ip
      t.string :user_agent
      t.datetime :created_at, null: false
    end

    add_index :otp_challenges, %i[phone_e164 created_at]
    add_check_constraint :otp_challenges, "attempts >= 0", name: "otp_challenges_attempts_check"
  end
end
