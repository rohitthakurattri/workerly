class QuotationItem < ApplicationRecord
  include AppendOnly

  TYPES = %w[labour material transport inspection other].freeze
  UNITS = %w[job item hour visit metre sq_ft kg litre].freeze
  CONDITIONS = %w[new refurbished used].freeze

  belongs_to :quotation_revision

  validates :item_type, inclusion: { in: TYPES }
  validates :unit, inclusion: { in: UNITS }
  validates :condition, inclusion: { in: CONDITIONS }, allow_nil: true
  validates :description, presence: true, length: { maximum: 200 }
  validates :brand, length: { maximum: 60 }
  validates :quantity, numericality: { greater_than: 0, less_than_or_equal_to: 10_000 }
  validates :unit_price_minor, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :warranty_days, numericality: { only_integer: true, in: 0..3650 }, allow_nil: true
end
