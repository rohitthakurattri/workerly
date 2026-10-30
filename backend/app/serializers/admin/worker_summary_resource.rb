module Admin
  class WorkerSummaryResource
    include Alba::Resource

    attribute(:id) { |p| p.public_id }
    attribute(:name) { |p| p.user.name }
    attribute(:phone) { |p| p.user.phone_e164 }
    attributes :verification_status, :experience_years
    attribute(:suspended) { |p| p.suspended? }
    attribute(:skills) { |p| p.service_categories.map(&:slug) }
    attribute(:submitted_at) { |p| p.submitted_at&.iso8601 }
    attribute(:created_at) { |p| p.created_at.iso8601 }
  end
end
