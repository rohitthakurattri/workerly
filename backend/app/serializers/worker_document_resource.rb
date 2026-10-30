class WorkerDocumentResource
  include Alba::Resource

  attribute(:id) { |d| d.public_id }
  attributes :kind, :doc_type, :number_last4, :status, :rejection_reason
  attribute(:reviewed_at) { |d| d.reviewed_at&.iso8601 }
  attribute(:uploaded_at) { |d| d.created_at.iso8601 }
  attribute(:file) { |d| FileResource.call(d.file) }
end
