# The customer's own view of a request, including what a draft still needs.
class ServiceRequestResource
  include Alba::Resource

  attribute(:id) { |r| r.public_id }
  attributes :status, :description, :answers, :ai_summary, :safety_flag, :urgency, :category_source
  attribute(:category) { |r| r.service_category && TriageResource::CategoryBrief.call(r.service_category) }
  attribute(:address) { |r| address_for(r) }
  attribute(:preferred_from) { |r| r.preferred_from&.iso8601 }
  attribute(:preferred_to) { |r| r.preferred_to&.iso8601 }
  attribute(:photos) { |r| r.photos.map { |a| RequestAttachmentResource.new(a).to_h } }
  attribute(:voice_note) { |r| r.voice_note && VoiceNoteResource.new(r.voice_note).to_h }
  attribute(:triage) { |r| triage_for(r) }
  attribute(:missing) { |r| r.draft? ? r.missing : [] }
  attribute(:cancellable) { |r| r.cancellable? }
  attribute(:cancel_reason) { |r| r.cancel_reason }
  attribute(:invited_count) { |r| r.invited_count }
  attribute(:matched_at) { |r| r.matched_at&.iso8601 }
  attribute(:quotes_count) { |r| r.draft? ? 0 : r.quotations.live.count }
  attribute(:booking_id) { |r| r.booked? || r.fulfilled? ? r.active_booking&.public_id : nil }
  attribute(:created_at) { |r| r.created_at.iso8601 }
  attribute(:submitted_at) { |r| r.submitted_at&.iso8601 }
  attribute(:expires_at) { |r| r.expires_at&.iso8601 }
  attribute(:cancelled_at) { |r| r.cancelled_at&.iso8601 }

  private

  # A submitted request shows the address as it was at submit time.
  def address_for(r)
    if r.draft?
      return r.address && r.address.deleted_at.nil? ? AddressResource.new(r.address).to_h : nil
    end

    r.address_snapshot.merge("id" => r.address.public_id, "city" => r.city.slug, "is_default" => false,
                             "location" => { lat: r.location_lat, lng: r.location_lng })
  end

  def triage_for(r)
    analysis = r.triage_analysis
    return nil unless analysis&.succeeded?

    result = Ai::Gateway::Result.new(analysis:, output: analysis.output)
    TriageResource.new(Ai::TriageRequest.build(result, ServiceCategory.requestable.index_by(&:slug))).to_h
  end
end
