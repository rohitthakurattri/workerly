# Immutable: a price change is a new revision. Booking approvals point at the exact row the customer saw.
class QuotationRevision < ApplicationRecord
  include AppendOnly

  STAGES = %w[initial inspection_fee final change_order].freeze

  has_public_id
  belongs_to :quotation
  belongs_to :created_by, class_name: "User"
  has_many :items, -> { order(:position) }, class_name: "QuotationItem", dependent: nil, inverse_of: :quotation_revision

  validates :stage, inclusion: { in: STAGES }
  validates :version, numericality: { only_integer: true, greater_than: 0 }
  validates :notes, length: { maximum: 1000 }
  validates :estimated_minutes, numericality: { only_integer: true, in: 1..20_160 }, allow_nil: true
  validates :currency_code, length: { is: 3 }
end
