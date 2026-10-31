# What an invited worker sees before booking: the problem, photos, area and a distance band.
# Never the customer's name, phone, exact address or exact distance; contact details typed
# into free text are masked.
class LeadResource
  include Alba::Resource

  attribute(:id) { |i| i.service_request.public_id }
  attribute(:status) { |i| i.declined? ? "declined" : (i.viewed_at ? "viewed" : "new") }
  attribute(:category) { |i| TriageResource::CategoryBrief.call(i.service_request.service_category) }
  attribute(:description) { |i| Shared::Redact.call(i.service_request.description) }
  attribute(:ai_summary) { |i| i.service_request.ai_summary && Shared::Redact.call(i.service_request.ai_summary) }
  attribute(:answers) do |i|
    i.service_request.answers.map { |a| { question: a["question"], answer: Shared::Redact.call(a["answer"]) } }
  end
  attribute(:urgency) { |i| i.service_request.urgency }
  attribute(:preferred_from) { |i| i.service_request.preferred_from&.iso8601 }
  attribute(:preferred_to) { |i| i.service_request.preferred_to&.iso8601 }
  attribute(:safety_flag) { |i| i.service_request.safety_flag }
  attribute(:locality) { |i| i.service_request.address_snapshot["locality"] }
  attribute(:city) { |i| i.service_request.city.slug }
  attribute(:distance_band) { |i| Matching::DistanceBand.call(i.distance_m) }
  attribute(:photos) { |i| i.service_request.photos.map { |a| RequestAttachmentResource.new(a).to_h } }
  attribute(:invited_at) { |i| i.created_at.iso8601 }
  attribute(:expires_at) { |i| i.service_request.expires_at.iso8601 }
end
