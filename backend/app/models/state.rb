class State < ApplicationRecord
  belongs_to :country
  has_many :cities, dependent: :restrict_with_error
  validates :code, presence: true, uniqueness: { scope: :country_id }
  validates :kind, inclusion: { in: %w[state union_territory] }
end
