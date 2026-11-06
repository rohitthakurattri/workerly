class Refund < ApplicationRecord
  STATUSES = %w[pending processed failed].freeze

  has_public_id
  belongs_to :payment
  belongs_to :initiated_by, class_name: "User"

  validates :status, inclusion: { in: STATUSES }
  validates :amount_minor, numericality: { only_integer: true, greater_than: 0 }
  validates :reason, presence: true, length: { maximum: 500 }

  def processed? = status == "processed"
end
