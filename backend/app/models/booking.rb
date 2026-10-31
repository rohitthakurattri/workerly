class Booking < ApplicationRecord
  STATUSES = %w[confirmed inspection_scheduled inspecting awaiting_final_approval closed_after_inspection
                scheduled in_progress awaiting_change_approval completed paid cancelled rejected disputed refunded].freeze
  # Not holding the request: a new booking may be made for it.
  INACTIVE_STATUSES = %w[cancelled rejected closed_after_inspection].freeze
  # The job is finished (reviews and disputes are possible).
  DONE_STATUSES = %w[completed paid disputed].freeze
  # The worker hasn't started the work yet.
  BEFORE_WORK_STATUSES = %w[confirmed inspection_scheduled scheduled].freeze

  has_public_id
  belongs_to :service_request
  belongs_to :quotation
  belongs_to :customer, class_name: "User"
  belongs_to :worker_profile
  belongs_to :pending_revision, class_name: "QuotationRevision", optional: true
  has_many :status_histories, -> { order(:created_at, :id) }, class_name: "BookingStatusHistory", dependent: :restrict_with_error
  has_many :approvals, -> { order(:created_at, :id) }, class_name: "BookingApproval", dependent: :restrict_with_error
  has_many :messages, -> { order(:created_at, :id) }, dependent: :restrict_with_error
  has_one :review, dependent: :restrict_with_error
  has_many :disputes, -> { order(:created_at, :id) }, dependent: :restrict_with_error

  validates :kind, inclusion: { in: Quotation::KINDS }
  validates :status, inclusion: { in: STATUSES }
  validates :cancel_reason, length: { maximum: 500 }

  scope :active, -> { where.not(status: INACTIVE_STATUSES) }

  STATUSES.each { |s| define_method(:"#{s}?") { status == s } }

  def done? = DONE_STATUSES.include?(status)
  def open_dispute = disputes.detect { |d| d.status == "open" }

  # Phone numbers and the full address are shared from confirmation until 48 h after completion
  # (BOOKING_CONTACT_HOURS), and never for a cancelled or closed booking.
  def contact_visible?(now = Time.current)
    return false if address_revealed_at.nil? || INACTIVE_STATUSES.include?(status)
    return true if completed_at.nil?

    now < completed_at + Workerly.config.booking_contact_hours.hours
  end

  # Chat follows the same window as contact details.
  def chat_open?(now = Time.current) = contact_visible?(now)
end
