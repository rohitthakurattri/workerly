class Message < ApplicationRecord
  include AppendOnly

  MAX_LENGTH = 2000

  has_public_id
  belongs_to :booking
  belongs_to :sender, class_name: "User"

  validates :sender_role, inclusion: { in: %w[customer worker] }
  validates :body, presence: true, length: { maximum: MAX_LENGTH }
end
