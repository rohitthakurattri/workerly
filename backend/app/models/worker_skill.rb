class WorkerSkill < ApplicationRecord
  belongs_to :worker_profile
  belongs_to :service_category

  validates :service_category_id, uniqueness: { scope: :worker_profile_id }
  validates :experience_years, numericality: { only_integer: true, in: 0..60 }, allow_nil: true
end
