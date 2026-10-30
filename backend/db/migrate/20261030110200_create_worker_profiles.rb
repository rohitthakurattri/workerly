class CreateWorkerProfiles < ActiveRecord::Migration[8.1]
  def change
    create_table :worker_profiles do |t|
      t.uuid :public_id, null: false
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.text :bio
      t.integer :experience_years
      t.string :verification_status, null: false, default: "draft"
      t.boolean :available, null: false, default: false
      t.decimal :rating_avg, precision: 3, scale: 2
      t.integer :rating_count, null: false, default: 0
      t.datetime :submitted_at
      t.datetime :approved_at
      t.datetime :suspended_at
      t.string :suspension_reason
      t.datetime :deleted_at
      t.timestamps
    end
    add_index :worker_profiles, :public_id, unique: true
    add_index :worker_profiles, %i[verification_status available]
    add_index :worker_profiles, %i[verification_status submitted_at]
    add_check_constraint :worker_profiles,
      "verification_status IN ('draft','pending_review','changes_requested','approved','rejected')",
      name: "worker_profiles_verification_status_check"
    add_check_constraint :worker_profiles, "experience_years IS NULL OR experience_years BETWEEN 0 AND 60",
      name: "worker_profiles_experience_check"
    # Only approved, unsuspended workers can be marked available for leads.
    add_check_constraint :worker_profiles,
      "NOT available OR (verification_status = 'approved' AND suspended_at IS NULL)",
      name: "worker_profiles_available_check"

    create_table :worker_skills do |t|
      t.references :worker_profile, null: false, foreign_key: true, index: false
      t.references :service_category, null: false, foreign_key: true
      t.integer :experience_years
      t.timestamps
    end
    add_index :worker_skills, %i[worker_profile_id service_category_id], unique: true
    add_check_constraint :worker_skills, "experience_years IS NULL OR experience_years BETWEEN 0 AND 60",
      name: "worker_skills_experience_check"

    create_table :worker_service_areas do |t|
      t.uuid :public_id, null: false
      t.references :worker_profile, null: false, foreign_key: true
      t.references :city, null: false, foreign_key: true
      t.string :label
      t.st_point :center, geographic: true, srid: 4326, null: false
      t.integer :radius_m, null: false
      t.timestamps
    end
    add_index :worker_service_areas, :public_id, unique: true
    add_index :worker_service_areas, :center, using: :gist
    add_check_constraint :worker_service_areas, "radius_m BETWEEN 500 AND 50000", name: "worker_service_areas_radius_check"
  end
end
