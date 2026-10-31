class IdempotencyKey < ApplicationRecord
  RETENTION = 24.hours

  belongs_to :user
  validates :key, presence: true, length: { maximum: 255 }

  def completed? = completed_at.present?
end
