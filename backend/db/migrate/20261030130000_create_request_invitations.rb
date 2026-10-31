class CreateRequestInvitations < ActiveRecord::Migration[8.1]
  def change
    # Which workers were offered a request. Only invited workers can see a request, and
    # (Phase 5) only invited workers can quote on it.
    create_table :request_invitations do |t|
      t.uuid :public_id, null: false
      t.references :service_request, null: false, foreign_key: true, index: false
      t.references :worker_profile, null: false, foreign_key: true, index: false
      t.integer :rank, null: false                       # 1 = best match
      t.decimal :rank_score, precision: 6, scale: 4, null: false
      t.integer :distance_m, null: false                 # to the nearest service-area centre
      t.datetime :notified_at
      t.string :notified_via                             # push | sms | none
      t.datetime :viewed_at
      t.datetime :declined_at
      t.string :decline_reason
      t.timestamps
    end
    add_index :request_invitations, :public_id, unique: true
    add_index :request_invitations, %i[service_request_id worker_profile_id], unique: true
    add_index :request_invitations, %i[worker_profile_id created_at]
    add_check_constraint :request_invitations, "rank > 0", name: "request_invitations_rank_check"
    add_check_constraint :request_invitations, "distance_m >= 0", name: "request_invitations_distance_check"
    add_check_constraint :request_invitations, "notified_via IS NULL OR notified_via IN ('push','sms','none')",
      name: "request_invitations_notified_via_check"

    add_column :service_requests, :matched_at, :datetime
    add_column :service_requests, :invited_count, :integer, null: false, default: 0
  end
end
