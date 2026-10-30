class AiAnalysis < ApplicationRecord
  include AppendOnly

  USE_CASES = %w[triage].freeze
  STATUSES = %w[succeeded failed].freeze

  has_public_id
  belongs_to :analysable, polymorphic: true
  belongs_to :user, optional: true
  belongs_to :suggested_category, class_name: "ServiceCategory", optional: true

  validates :use_case, inclusion: { in: USE_CASES }
  validates :status, inclusion: { in: STATUSES }
  validates :provider, :prompt_version, :input_hash, presence: true

  scope :succeeded, -> { where(status: "succeeded") }
  scope :failed, -> { where(status: "failed") }

  def succeeded? = status == "succeeded"
end
