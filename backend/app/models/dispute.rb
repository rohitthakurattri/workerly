class Dispute < ApplicationRecord
  CATEGORIES = %w[no_show quality overcharge damage behaviour other].freeze
  STATUSES = %w[open resolved].freeze

  has_public_id
  belongs_to :booking
  belongs_to :raised_by, class_name: "User"
  belongs_to :resolved_by, class_name: "User", optional: true

  validates :category, inclusion: { in: CATEGORIES }
  validates :status, inclusion: { in: STATUSES }
  validates :description, presence: true, length: { maximum: 2000 }
  validates :resolution, length: { maximum: 2000 }

  def open? = status == "open"
end
