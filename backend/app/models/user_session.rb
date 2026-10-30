# One login on one device. Refresh tokens rotate inside it; revoking it ends every token in the family.
class UserSession < ApplicationRecord
  SCOPES = %w[consumer staff].freeze

  has_public_id
  belongs_to :user
  has_many :refresh_tokens, dependent: :delete_all

  validates :scope, inclusion: { in: SCOPES }

  def active? = revoked_at.nil? && expires_at.future?
  def staff? = scope == "staff"

  def revoke!(reason)
    update!(revoked_at: Time.current, revoke_reason: reason) if revoked_at.nil?
  end
end
