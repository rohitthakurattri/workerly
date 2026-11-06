# A webhook exactly as the gateway sent it. Append-only; unique per provider event id.
class PaymentEvent < ApplicationRecord
  include AppendOnly
end
