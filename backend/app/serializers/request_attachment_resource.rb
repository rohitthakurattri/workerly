class RequestAttachmentResource
  include Alba::Resource

  attribute(:id) { |a| a.public_id }
  attributes :kind, :width, :height
  attribute(:file) { |a| FileResource.call(a.file) }
end
