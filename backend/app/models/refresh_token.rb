class RefreshToken < ApplicationRecord
  belongs_to :user_session

  def self.digest(raw) = OpenSSL::HMAC.hexdigest("SHA256", Workerly.config.token_pepper, raw.to_s)
  def self.find_by_raw(raw) = raw.present? ? find_by(token_digest: digest(raw)) : nil

  def rotated? = rotated_at.present?
  def expired? = expires_at.past?
end
