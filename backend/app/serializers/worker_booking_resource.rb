# The booked worker now sees the customer's own words (unredacted), photos, name and phone.
class WorkerBookingResource < BookingResource
  attribute(:customer) do |b|
    b.contact_revealed? ? { name: b.customer.name, phone: b.customer.phone_e164 } : nil
  end
  attribute(:description) { |b| b.contact_revealed? ? b.service_request.description : Shared::Redact.call(b.service_request.description) }
  attribute(:answers) { |b| b.service_request.answers }
  attribute(:urgency) { |b| b.service_request.urgency }
  attribute(:photos) { |b| b.service_request.photos.map { |a| RequestAttachmentResource.new(a).to_h } }
end
