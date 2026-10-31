class Booking < ApplicationRecord
  # Phase 5 creates bookings in `confirmed`; the rest of the lifecycle arrives in Phase 6.
  STATUSES = %w[confirmed inspection_scheduled inspecting awaiting_final_approval closed_after_inspection
                scheduled in_progress awaiting_change_approval completed paid cancelled rejected disputed refunded].freeze
  INACTIVE_STATUSES = %w[cancelled rejected].freeze

  has_public_id
  belongs_to :service_request
  belongs_to :quotation
  belongs_to :customer, class_name: "User"
  belongs_to :worker_profile
  has_many :status_histories, -> { order(:created_at, :id) }, class_name: "BookingStatusHistory", dependent: :restrict_with_error
  has_many :approvals, -> { order(:created_at, :id) }, class_name: "BookingApproval", dependent: :restrict_with_error

  validates :kind, inclusion: { in: Quotation::KINDS }
  validates :status, inclusion: { in: STATUSES }

  scope :active, -> { where.not(status: INACTIVE_STATUSES) }

  def contact_revealed? = address_revealed_at.present?
end
