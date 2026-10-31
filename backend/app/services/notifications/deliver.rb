module Notifications
  # Records an in-app notification, sends web push, and falls back to SMS for critical events
  # when no device took the push. Call from a job, never inside a request.
  module Deliver
    module_function

    def call(user:, app:, kind:, title:, body: nil, url: nil, data: {}, sms: nil)
      notification = user.notifications.create!(kind:, title:, body:, url:, data:, channels: [ "in_app" ])
      channels = [ "in_app" ]
      pushed = Push.deliver(user:, app:, payload: { id: notification.public_id, kind:, title:, body:, url:, data: })
      channels << "push" if pushed
      if !pushed && sms
        Adapters::Sms.adapter.deliver(to: user.phone_e164, body: sms)
        channels << "sms"
      end
      notification.update_columns(channels:)
      notification
    end
  end
end
