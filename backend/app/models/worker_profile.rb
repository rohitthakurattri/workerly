class WorkerProfile < ApplicationRecord
  include AttachmentRules

  STATUSES = %w[draft pending_review changes_requested approved rejected].freeze
  # Statuses in which the worker may still edit documents and resubmit.
  EDITABLE_STATUSES = %w[draft changes_requested].freeze
  MAX_SKILLS = 10
  MAX_SERVICE_AREAS = 3

  has_public_id
  belongs_to :user
  has_many :worker_skills, dependent: :destroy
  has_many :service_categories, through: :worker_skills
  has_many :service_areas, class_name: "WorkerServiceArea", dependent: :destroy
  has_many :documents, class_name: "WorkerDocument", dependent: :destroy
  has_many :verifications, -> { order(:created_at, :id) }, class_name: "WorkerVerification", dependent: :restrict_with_error
  has_one_attached :photo

  attachment_rules :photo, types: AttachmentRules::IMAGE_TYPES, max_size: 5.megabytes
  validates :verification_status, inclusion: { in: STATUSES }
  validates :bio, length: { maximum: 1000 }
  validates :experience_years, numericality: { only_integer: true, in: 0..60 }, allow_nil: true

  scope :kept, -> { where(deleted_at: nil) }

  STATUSES.each { |s| define_method(:"#{s}?") { verification_status == s } }

  def suspended? = suspended_at.present?
  def editable? = EDITABLE_STATUSES.include?(verification_status)
  def can_receive_leads? = approved? && !suspended? && user.active?
  def live_documents = documents.where(status: %w[pending approved])
end
