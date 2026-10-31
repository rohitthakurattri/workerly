# Proof of consent: who approved which exact revision, when, and from where.
class BookingApproval < ApplicationRecord
  include AppendOnly

  DECISIONS = %w[approved rejected].freeze

  belongs_to :booking
  belongs_to :quotation_revision
  belongs_to :decided_by, class_name: "User"
  validates :decision, inclusion: { in: DECISIONS }

  def approved? = decision == "approved"
end
