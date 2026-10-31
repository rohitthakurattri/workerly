class BookingStatusHistory < ApplicationRecord
  include AppendOnly

  belongs_to :booking
  belongs_to :actor, class_name: "User", optional: true
  validates :to_status, inclusion: { in: Booking::STATUSES }
end
