module Admin
  class WorkerDetailResource
    include Alba::Resource

    attribute(:id) { |p| p.public_id }
    attribute(:user) { |p| { id: p.user.public_id, name: p.user.name, phone: p.user.phone_e164, created_at: p.user.created_at.iso8601 } }
    attributes :bio, :experience_years, :verification_status, :suspension_reason
    attribute(:suspended) { |p| p.suspended? }
    attribute(:submitted_at) { |p| p.submitted_at&.iso8601 }
    attribute(:approved_at) { |p| p.approved_at&.iso8601 }
    attribute(:photo) { |p| FileResource.call(p.photo) }
    attribute(:skills) do |p|
      p.worker_skills.includes(:service_category).map { |s| { category: s.service_category.slug, name: s.service_category.name("en"), experience_years: s.experience_years } }
    end
    attribute(:service_areas) { |p| p.service_areas.includes(:city).map { |a| WorkerServiceAreaResource.new(a).to_h } }
    attribute(:documents) { |p| p.documents.order(:created_at).map { |d| WorkerDocumentResource.new(d).to_h } }
    attribute(:missing) { |p| Workers::Requirements.missing(p) }
    attribute(:history) do |p|
      p.verifications.includes(:admin).map do |v|
        { decision: v.decision, reason: v.reason, documents: v.document_decisions,
          by: v.admin.name || v.admin.phone_e164, at: v.created_at.iso8601 }
      end
    end
  end
end
