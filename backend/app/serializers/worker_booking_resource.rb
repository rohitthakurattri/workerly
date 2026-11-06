# The booked worker sees the customer's own words (unredacted), photos, name and phone while the
# contact window is open.
class WorkerBookingResource < BookingResource
  attribute(:customer) do |b|
    b.contact_visible? ? { name: b.customer.name, phone: b.customer.phone_e164 } : nil
  end
  attribute(:description) { |b| b.contact_visible? ? b.service_request.description : Shared::Redact.call(b.service_request.description) }
  attribute(:answers) { |b| b.service_request.answers }
  attribute(:urgency) { |b| b.service_request.urgency }
  attribute(:photos) { |b| b.service_request.photos.map { |a| RequestAttachmentResource.new(a).to_h } }
  attribute(:voice_note) do |b|
    v = b.service_request.voice_note
    v && VoiceNoteResource.new(v, params: { redact: !b.contact_visible?, audio: b.contact_visible? }).to_h
  end
  attribute(:currency) { |b| b.currency_code }
  attribute(:tax_rate_bps) { |b| b.service_request.service_category.tax_rate_bps }

  private

  def viewer_role = "worker"
end
