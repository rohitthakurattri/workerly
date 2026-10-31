module Bookings
  # In-booking chat. Open while contact details are (until 48 h after completion).
  module PostMessage
    module_function

    NOTIFY_EVERY = 10.minutes

    def call(booking:, sender:, role:, body:)
      raise ApplicationError.new(:chat_closed, status: :conflict) unless booking.chat_open?

      message = booking.messages.create!(sender:, sender_role: role, body: body.to_s.strip)
      BookingChannel.broadcast_to(booking, { type: "message.new", message: MessageResource.new(message).to_h })
      recipient_role = role == "customer" ? "worker" : "customer"
      # One push per conversation burst, not one per message.
      if Rails.cache.write("chat_notify:#{booking.id}:#{recipient_role}", 1, unless_exist: true, expires_in: NOTIFY_EVERY)
        MessageNotifyJob.perform_later(message.id, recipient_role)
      end
      message
    end
  end
end
