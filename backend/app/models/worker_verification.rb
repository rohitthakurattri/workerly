class WorkerVerification < ApplicationRecord
  include AppendOnly

  DECISIONS = %w[approved changes_requested rejected suspended reinstated].freeze

  belongs_to :worker_profile
  belongs_to :admin, class_name: "User"
  validates :decision, inclusion: { in: DECISIONS }
end
