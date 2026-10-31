class Notification < ApplicationRecord
  has_public_id
  belongs_to :user

  validates :kind, :title, presence: true
  validates :title, length: { maximum: 120 }
  validates :body, length: { maximum: 300 }

  scope :unread, -> { where(read_at: nil) }
end
