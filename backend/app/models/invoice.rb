class Invoice < ApplicationRecord
  include AppendOnly

  has_public_id
  belongs_to :booking
end
