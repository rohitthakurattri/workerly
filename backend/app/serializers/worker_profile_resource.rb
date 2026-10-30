# The worker's own view of their profile, including what's left to do.
class WorkerProfileResource
  include Alba::Resource

  attribute(:id) { |p| p.public_id }
  attributes :bio, :experience_years, :verification_status, :available, :rating_count
  attribute(:rating_avg) { |p| p.rating_avg&.to_f }
  attribute(:editable) { |p| p.editable? }
  attribute(:suspended) { |p| p.suspended? }
  attribute(:submitted_at) { |p| p.submitted_at&.iso8601 }
  attribute(:approved_at) { |p| p.approved_at&.iso8601 }
  attribute(:photo) { |p| FileResource.call(p.photo) }
  attribute(:skills) do |p|
    p.worker_skills.includes(:service_category).map { |s| { category: s.service_category.slug, name: s.service_category.name, experience_years: s.experience_years } }
  end
  attribute(:service_areas) { |p| p.service_areas.includes(:city).map { |a| WorkerServiceAreaResource.new(a).to_h } }
  attribute(:documents) { |p| p.documents.order(:created_at).map { |d| WorkerDocumentResource.new(d).to_h } }
  attribute(:missing) { |p| Workers::Requirements.missing(p) }
  # Reviewers' message for the latest decision (e.g. what to fix), never the reviewer's identity.
  attribute(:last_decision) do |p|
    v = p.verifications.last
    v && { decision: v.decision, reason: v.reason, decided_at: v.created_at.iso8601 }
  end
end
