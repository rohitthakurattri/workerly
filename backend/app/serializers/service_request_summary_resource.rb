# One row of the customer's dashboard list.
class ServiceRequestSummaryResource
  include Alba::Resource

  attribute(:id) { |r| r.public_id }
  attributes :status, :urgency
  attribute(:title) { |r| r.description.to_s.squish.truncate(90).presence }
  attribute(:category) { |r| r.service_category && TriageResource::CategoryBrief.call(r.service_category) }
  attribute(:locality) { |r| r.address_snapshot&.dig("locality") || r.address&.locality }
  attribute(:photo_count) { |r| r.photos.size }
  attribute(:cover) { |r| FileResource.call(r.photos.first&.file) }
  attribute(:created_at) { |r| r.created_at.iso8601 }
  attribute(:submitted_at) { |r| r.submitted_at&.iso8601 }
  attribute(:expires_at) { |r| r.expires_at&.iso8601 }
end
