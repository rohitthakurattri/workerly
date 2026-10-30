class OtpChallenge < ApplicationRecord
  MAX_ATTEMPTS = 5

  scope :for_phone, ->(phone) { where(phone_e164: phone) }
  scope :pending, -> { where(consumed_at: nil, invalidated_at: nil).where("expires_at > ?", Time.current) }

  def exhausted? = attempts >= MAX_ATTEMPTS
end
