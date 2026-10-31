module Bookings
  # Tells the other party about a booking event (in-app + push). Admin cancellations go to both.
  class NotifyJob < ApplicationJob
    queue_as :default

    CUSTOMER_EVENTS = %w[schedule check_in final_quotation start change_order complete cancel admin_cancel resolve_dispute].freeze
    WORKER_EVENTS = %w[approve_final reject_final approve_change reject_change cancel admin_cancel dispute resolve_dispute].freeze

    def perform(booking_id, event, actor_role)
      booking = Booking.includes(:customer, :pending_revision, worker_profile: :user, service_request: :service_category).find(booking_id)
      recipients = []
      recipients << [ booking.customer, "customer", "/bookings/#{booking.public_id}" ] if CUSTOMER_EVENTS.include?(event) && actor_role != "customer"
      recipients << [ booking.worker_profile.user, "worker", "/jobs/#{booking.public_id}" ] if WORKER_EVENTS.include?(event) && actor_role != "worker"

      recipients.each do |user, app, url|
        Notifications::Deliver.call(
          user:, app:, kind: "booking.#{event}", url:, data: { booking_id: booking.public_id },
          title: I18n.t("notifications.booking.#{event}", **vars(booking, user), locale: user.locale)
        )
      end
    end

    private

    def vars(booking, user)
      revision = booking.pending_revision
      time = booking.scheduled_at&.in_time_zone(booking.service_request.city&.time_zone || "Asia/Kolkata")
      { worker: booking.worker_profile.user.name, customer: booking.customer.name,
        category: booking.service_request.service_category.name(user.locale),
        amount: revision && Shared::Money.format(revision.total_minor, revision.currency_code),
        time: time&.strftime("%-d %b, %-l:%M %p") }
    end
  end
end
