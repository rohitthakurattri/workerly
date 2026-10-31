# A browser push subscription. The endpoint is a capability URL, so it is treated as a secret.
class DeviceSubscription < ApplicationRecord
  APPS = %w[customer worker].freeze
  # The server POSTs to the endpoint, so only real browser push services are accepted (no SSRF).
  PUSH_HOSTS = /\A(fcm\.googleapis\.com|updates\.push\.services\.mozilla\.com|[a-z0-9-]+\.push\.apple\.com|[a-z0-9-]+\.notify\.windows\.com)\z/

  has_public_id
  belongs_to :user
  encrypts :p256dh, :auth

  validates :app, inclusion: { in: APPS }
  validates :endpoint, presence: true, length: { maximum: 2000 }
  validate :endpoint_is_a_push_service
  validates :p256dh, :auth, presence: true

  scope :working, -> { where(failed_at: nil) }

  private

  def endpoint_is_a_push_service
    uri = URI.parse(endpoint.to_s)
    return if uri.is_a?(URI::HTTPS) && uri.port == 443 && uri.userinfo.nil? && PUSH_HOSTS.match?(uri.host.to_s)

    errors.add(:endpoint, "must be a browser push service URL")
  rescue URI::InvalidURIError
    errors.add(:endpoint, "is not a valid URL")
  end
end
