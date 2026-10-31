class Review < ApplicationRecord
  include AppendOnly

  has_public_id
  belongs_to :booking
  belongs_to :reviewer, class_name: "User"
  belongs_to :worker_profile

  validates :rating, numericality: { only_integer: true, in: 1..5 }
  validates :body, length: { maximum: 1000 }
end
