class Payment < ApplicationRecord
  METHODS = %w[online cash].freeze
  STATUSES = %w[created captured failed refunded partially_refunded amount_mismatch].freeze
  # Money Workerly has received (and possibly partly returned).
  SETTLED_STATUSES = %w[captured refunded partially_refunded].freeze

  has_public_id
  belongs_to :booking
  belongs_to :recorded_by, class_name: "User", optional: true
  has_many :refunds, dependent: :restrict_with_error

  validates :method, inclusion: { in: METHODS }
  validates :status, inclusion: { in: STATUSES }
  validates :amount_minor, numericality: { only_integer: true, greater_than: 0 }

  scope :settled, -> { where(status: SETTLED_STATUSES) }

  STATUSES.each { |s| define_method(:"#{s}?") { status == s } }

  def settled? = SETTLED_STATUSES.include?(status)
  def refundable_minor = settled? && online? ? amount_minor - refunded_minor - refunds.where(status: "pending").sum(:amount_minor) : 0
  def online? = method == "online"
end
