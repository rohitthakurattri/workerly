module Bookings
  class MessageNotifyJob < ApplicationJob
    queue_as :default

    def perform(message_id, recipient_role)
      message = Message.includes(:sender, booking: [ :customer, { worker_profile: :user } ]).find(message_id)
      booking = message.booking
      user, url = recipient_role == "customer" ? [ booking.customer, "/bookings/#{booking.public_id}" ] : [ booking.worker_profile.user, "/jobs/#{booking.public_id}" ]
      Notifications::Deliver.call(
        user:, app: recipient_role, kind: "booking.message", url:, data: { booking_id: booking.public_id },
        title: I18n.t("notifications.booking.message", name: message.sender.name, locale: user.locale),
        body: message.body.truncate(120)
      )
    end
  end
end
