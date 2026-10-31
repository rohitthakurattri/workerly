# A booking as either party sees it. Contact details and the full address are shared from
# confirmation until 48 h after completion (Booking#contact_visible?).
class BookingResource
  include Alba::Resource

  attribute(:id) { |b| b.public_id }
  attributes :status, :kind
  attribute(:request_id) { |b| b.service_request.public_id }
  attribute(:category) { |b| TriageResource::CategoryBrief.call(b.service_request.service_category) }
  # What the customer owes: only ever the sum of approved revisions (Bookings::AmountDue).
  attribute(:approved_total) { |b| Shared::Money.to_h(b.approved_total_minor, b.currency_code) }
  attribute(:revision) { |b| QuotationRevisionResource.new(b.approvals.find(&:approved?)&.quotation_revision || b.quotation.current_revision).to_h }
  attribute(:pending_revision) { |b| b.pending_revision && QuotationRevisionResource.new(b.pending_revision).to_h }
  attribute(:approvals) do |b|
    b.approvals.map do |a|
      r = a.quotation_revision
      { revision_id: r.public_id, version: r.version, stage: r.stage, decision: a.decision,
        total: Shared::Money.to_h(r.total_minor, r.currency_code), decided_at: a.created_at.iso8601 }
    end
  end
  attribute(:history) do |b|
    b.status_histories.map { |h| { from: h.from_status, to: h.to_status, event: h.metadata["event"], by: h.actor_role, at: h.created_at.iso8601 } }
  end
  attribute(:quotation_id) { |b| b.quotation.public_id }
  attribute(:preferred_from) { |b| b.service_request.preferred_from&.iso8601 }
  attribute(:preferred_to) { |b| b.service_request.preferred_to&.iso8601 }
  attribute(:confirmed_at) { |b| b.confirmed_at.iso8601 }
  attribute(:scheduled_at) { |b| b.scheduled_at&.iso8601 }
  attribute(:checked_in_at) { |b| b.checked_in_at&.iso8601 }
  attribute(:started_at) { |b| b.started_at&.iso8601 }
  attribute(:completed_at) { |b| b.completed_at&.iso8601 }
  attribute(:cancelled_at) { |b| b.cancelled_at&.iso8601 }
  attributes :cancelled_by, :cancel_reason
  attribute(:contact_visible) { |b| b.contact_visible? }
  attribute(:chat_open) { |b| b.chat_open? }
  attribute(:address) { |b| b.contact_visible? ? address_for(b.service_request) : nil }
  attribute(:actions) { |b| visible_actions(b) }
  attribute(:review) { |b| b.review && { rating: b.review.rating, body: b.review.body, created_at: b.review.created_at.iso8601 } }
  attribute(:dispute) do |b|
    d = b.disputes.last
    d && { id: d.public_id, category: d.category, description: d.description, status: d.status,
           resolution: d.resolution, created_at: d.created_at.iso8601, resolved_at: d.resolved_at&.iso8601 }
  end

  private

  # Buttons the viewer can press now. Disputes have their own flag (window rules).
  def visible_actions(b) = Bookings::Transitions.available(b, viewer_role) - %w[dispute admin_cancel resolve_dispute]

  def address_for(r)
    r.address_snapshot.merge("city" => r.city.slug, "location" => { lat: r.location_lat, lng: r.location_lng })
  end
end
