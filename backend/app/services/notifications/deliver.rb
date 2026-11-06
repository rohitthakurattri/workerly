module Notifications
  # Records an in-app notification, sends web push, and falls back to SMS for critical events
  # when no device took the push. Call from a job, never inside a request.
  module Deliver
    module_function

    # sms: an Adapters::Sms::Message (registered template) sent only if no device took the push.
    def call(user:, app:, kind:, title:, body: nil, url: nil, data: {}, sms: nil)
      notification = user.notifications.create!(kind:, title:, body:, url:, data:, channels: [ "in_app" ])
      channels = [ "in_app" ]
      pushed = Push.deliver(user:, app:, payload: { id: notification.public_id, kind:, title:, body:, url:, data: })
      channels << "push" if pushed
      channels << "sms" if !pushed && sms && send_sms(user, sms, kind)
      notification.update_columns(channels:)
      notification
    end

    # A failed SMS must not fail (and retry) the job: the in-app notification is already saved.
    def send_sms(user, message, kind)
      Adapters::Sms.adapter.deliver(to: user.phone_e164, message:)
    rescue Adapters::Sms::Error => e
      Rails.logger.error("[Notifications] SMS #{kind} to user #{user.id} failed: #{e.code} #{e.message}")
      false
    end
  end
end
