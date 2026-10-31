class User < ApplicationRecord
  CONSUMER_ROLES = %w[customer worker].freeze
  STAFF_ROLES = %w[admin finance support verifier].freeze # ordered by default preference
  ROLES = (CONSUMER_ROLES + STAFF_ROLES).freeze
  STATUSES = %w[active suspended].freeze
  LOCALES = %w[en hi pa].freeze

  has_public_id
  encrypts :totp_secret

  has_many :user_roles, dependent: :destroy
  has_many :user_sessions, dependent: :destroy
  has_one :worker_profile, dependent: :restrict_with_error
  has_many :addresses, dependent: :restrict_with_error
  has_many :service_requests, foreign_key: :customer_id, inverse_of: :customer, dependent: :restrict_with_error
  has_many :notifications, dependent: :destroy
  has_many :device_subscriptions, dependent: :destroy

  validates :phone_e164, presence: true, format: { with: Identity::PhoneNumber::E164 }
  validates :status, inclusion: { in: STATUSES }
  validates :locale, inclusion: { in: LOCALES }
  validates :name, length: { maximum: 100 }
  validates :email, length: { maximum: 254 }, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true

  scope :kept, -> { where(deleted_at: nil) }

  def roles = user_roles.map(&:role)
  def role?(role) = roles.include?(role.to_s)
  def staff? = roles.intersect?(STAFF_ROLES)
  def active? = status == "active" && deleted_at.nil?
  def totp_enabled? = totp_enabled_at.present? && totp_secret.present?

  def roles_for_scope(scope)
    allowed = scope.to_s == "staff" ? STAFF_ROLES : CONSUMER_ROLES
    allowed & roles
  end

  def grant_role!(role, granted_by: nil)
    user_roles.find_or_create_by!(role: role.to_s) { |r| r.granted_by = granted_by }
  end
end
