class Country < ApplicationRecord
  has_many :states, dependent: :restrict_with_error
  validates :iso2, presence: true, uniqueness: true, length: { is: 2 }
end
