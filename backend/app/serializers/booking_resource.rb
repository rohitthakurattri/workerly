# A booking as either party sees it. Contact details and the full address are shared only once
# the booking is confirmed (address_revealed_at); Phase 6 hides them again after completion.
class BookingResource
  include Alba::Resource

  attribute(:id) { |b| b.public_id }
  attributes :status, :kind
  attribute(:request_id) { |b| b.service_request.public_id }
  attribute(:category) { |b| TriageResource::CategoryBrief.call(b.service_request.service_category) }
  attribute(:approved_total) { |b| Shared::Money.to_h(b.approved_total_minor, b.currency_code) }
  attribute(:revision) { |b| QuotationRevisionResource.new(b.approvals.find(&:approved?)&.quotation_revision || b.quotation.current_revision).to_h }
  attribute(:quotation_id) { |b| b.quotation.public_id }
  attribute(:preferred_from) { |b| b.service_request.preferred_from&.iso8601 }
  attribute(:preferred_to) { |b| b.service_request.preferred_to&.iso8601 }
  attribute(:confirmed_at) { |b| b.confirmed_at.iso8601 }
  attribute(:address) { |b| b.contact_revealed? ? address_for(b.service_request) : nil }

  private

  def address_for(r)
    r.address_snapshot.merge("city" => r.city.slug, "location" => { lat: r.location_lat, lng: r.location_lng })
  end
end
