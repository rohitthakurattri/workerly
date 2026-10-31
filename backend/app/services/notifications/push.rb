module Notifications
  # Web push to a user's subscribed browsers for one app. Returns true if any device accepted it.
  module Push
    module_function

    def enabled? = Workerly.config.vapid_public_key.present? && Workerly.config.vapid_private_key.present?

    def deliver(user:, app:, payload:)
      return false unless enabled?

      user.device_subscriptions.working.where(app:).to_a.count { |sub| send_to(sub, payload) }.positive?
    end

    def send_to(sub, payload)
      WebPush.payload_send(
        message: payload.to_json, endpoint: sub.endpoint, p256dh: sub.p256dh, auth: sub.auth,
        vapid: { subject: Workerly.config.vapid_subject, public_key: Workerly.config.vapid_public_key,
                 private_key: Workerly.config.vapid_private_key },
        ttl: 1.hour.to_i, urgency: "high", open_timeout: 5, read_timeout: 5
      )
      sub.update_columns(last_seen_at: Time.current)
      true
    rescue WebPush::ExpiredSubscription, WebPush::InvalidSubscription
      sub.destroy # the browser unsubscribed or the endpoint is gone
      false
    rescue WebPush::Unauthorized
      sub.update_columns(failed_at: Time.current) # VAPID keys changed; the app re-subscribes on next visit
      false
    rescue WebPush::ResponseError, Net::OpenTimeout, Net::ReadTimeout, SocketError, SystemCallError, OpenSSL::SSL::SSLError => e
      Rails.logger.warn("[Push] #{e.class} for subscription #{sub.id}")
      false
    end
  end
end
