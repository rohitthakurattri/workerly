class Quotation < ApplicationRecord
  KINDS = %w[fixed inspection].freeze
  STATUSES = %w[submitted accepted declined withdrawn expired].freeze
  # Counts towards the request's quote limit and is shown to the customer.
  LIVE_STATUSES = %w[submitted accepted].freeze
  MAX_REVISIONS = 10

  has_public_id
  belongs_to :service_request
  belongs_to :worker_profile
  belongs_to :invitation, class_name: "RequestInvitation", foreign_key: :request_invitation_id, inverse_of: :quotation
  has_many :revisions, -> { order(:version) }, class_name: "QuotationRevision", dependent: :restrict_with_error
  has_one :booking, dependent: :restrict_with_error

  validates :kind, inclusion: { in: KINDS }
  validates :status, inclusion: { in: STATUSES }
  validates :decline_reason, length: { maximum: 300 }

  scope :live, -> { where(status: LIVE_STATUSES) }

  STATUSES.each { |s| define_method(:"#{s}?") { status == s } }

  def lapsed?(now = Time.current) = submitted? && valid_until <= now
  # What the apps show: a submitted quote past valid_until reads as expired before the sweep catches it.
  def effective_status(now = Time.current) = lapsed?(now) ? "expired" : status
  # Uses preloaded revisions when present (lists preload revisions: :items).
  def current_revision = revisions.detect { |r| r.version == current_version }
  def stage = kind == "inspection" ? "inspection_fee" : "initial"
end
