class RequestAttachment < ApplicationRecord
  include AttachmentRules

  KINDS = %w[image audio video].freeze

  has_public_id
  belongs_to :service_request
  has_one_attached :file

  # Images are re-encoded to JPEG on upload (Requests::AddPhoto), which also strips EXIF/GPS.
  attachment_rules :file, types: %w[image/jpeg], max_size: 10.megabytes, required: true
  validates :kind, inclusion: { in: KINDS }
end
