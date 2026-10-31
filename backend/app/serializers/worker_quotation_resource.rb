# The worker's own quote, with the request it belongs to.
class WorkerQuotationResource
  include Alba::Resource

  attribute(:id) { |q| q.public_id }
  attribute(:lead_id) { |q| q.service_request.public_id }
  attributes :kind, :current_version
  attribute(:status) { |q| q.effective_status }
  attribute(:valid_until) { |q| q.valid_until.iso8601 }
  attribute(:submitted_at) { |q| q.created_at.iso8601 }
  attribute(:revision) { |q| QuotationRevisionResource.new(q.current_revision).to_h }
  attribute(:category) { |q| TriageResource::CategoryBrief.call(q.service_request.service_category) }
  attribute(:locality) { |q| q.service_request.address_snapshot["locality"] }
  attribute(:editable) { |q| q.submitted? && !q.lapsed? && q.service_request.quotable? && q.current_version < Quotation::MAX_REVISIONS }
  attribute(:booking_id) { |q| q.accepted? ? q.booking&.public_id : nil }
  attribute(:decline_reason) { |q| q.declined? && q.decline_reason != "another_accepted" ? q.decline_reason : nil }
end
