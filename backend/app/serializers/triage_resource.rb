# An Ai::TriageRequest::Suggestion. Everything here is labelled "suggested" in the apps.
class TriageResource
  include Alba::Resource

  attribute(:id) { |s| s.analysis.public_id }
  attribute(:suggested_category) { |s| s.category && CategoryBrief.call(s.category) }
  attributes :confidence, :summary, :questions, :urgency, :safety_flag
  attribute(:alternatives) { |s| s.alternatives.map { |c| CategoryBrief.call(c) } }
  attribute(:needs_confirmation) { |s| s.needs_confirmation? }

  module CategoryBrief
    def self.call(c) = { slug: c.slug, name: c.name, icon: c.icon }
  end
end
