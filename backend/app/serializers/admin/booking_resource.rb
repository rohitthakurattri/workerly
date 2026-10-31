module Admin
  # Support's view: both parties, every event, every approval, the chat and any dispute.
  class BookingResource < ::BookingResource
    attribute(:customer) { |b| { id: b.customer.public_id, name: b.customer.name, phone: b.customer.phone_e164 } }
    attribute(:worker) { |b| { id: b.worker_profile.public_id, name: b.worker_profile.user.name, phone: b.worker_profile.user.phone_e164 } }
    attribute(:messages) { |b| b.messages.includes(:sender).map { |m| MessageResource.new(m).to_h } }
    attribute(:locality) { |b| b.service_request.address_snapshot["locality"] }

    private

    def viewer_role = "admin"
    def visible_actions(b) = Bookings::Transitions.available(b, "admin") & %w[admin_cancel]
  end
end
