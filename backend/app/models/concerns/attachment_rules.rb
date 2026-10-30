# Size and type limits for uploads. Active Storage sniffs the real content type
# from the file bytes (Marcel), so a renamed .exe is not accepted as a JPEG.
module AttachmentRules
  extend ActiveSupport::Concern

  IMAGE_TYPES = %w[image/jpeg image/png image/webp image/heic image/heif].freeze
  DOCUMENT_TYPES = (IMAGE_TYPES + %w[application/pdf]).freeze

  class_methods do
    def attachment_rules(name, types:, max_size:, required: false)
      validate do
        attachment = public_send(name)
        if !attachment.attached?
          errors.add(name, :blank) if required
          next
        end
        blob = attachment.blob
        errors.add(name, "must be one of: #{types.map { |t| t.split('/').last }.join(', ')}") unless types.include?(blob.content_type)
        errors.add(name, "must be smaller than #{max_size / 1.megabyte} MB") if blob.byte_size > max_size
      end
    end
  end
end
