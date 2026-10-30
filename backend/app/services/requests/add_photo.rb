module Requests
  # Adds a photo to a draft. Every image is re-encoded to a JPEG of at most 2048 px: this strips
  # EXIF (including the GPS position of the customer's home), applies the camera rotation and keeps
  # files small for workers on mobile data.
  module AddPhoto
    module_function

    MAX_SIDE = 2048
    MAX_UPLOAD = 10.megabytes

    def call(request:, file:)
      raise ApplicationError.new(:request_locked, status: :conflict) unless request.draft?

      validate_upload!(file)
      processed = process(file)
      ServiceRequest.transaction do
        request.lock!
        if request.attachments.where(kind: "image").count >= ServiceRequest::MAX_PHOTOS
          raise ApplicationError.new(:too_many_photos, details: { max: ServiceRequest::MAX_PHOTOS })
        end

        width, height = MiniMagick::Image.new(processed.path).dimensions
        request.attachments.create!(kind: "image", width:, height:,
                                    file: { io: File.open(processed.path), filename: "photo-#{SecureRandom.hex(4)}.jpg", content_type: "image/jpeg" })
      end
    ensure
      processed&.close!
    end

    # Content type is sniffed from the bytes (Marcel), not taken from the browser.
    def validate_upload!(file)
      type = Marcel::MimeType.for(file.tempfile, name: file.original_filename)
      unless AttachmentRules::IMAGE_TYPES.include?(type)
        raise ApplicationError.new(:validation_failed, details: { field_errors: { file: [ "must be a photo (JPEG, PNG, WebP or HEIC)" ] } })
      end
      return if file.size <= MAX_UPLOAD

      raise ApplicationError.new(:validation_failed, details: { field_errors: { file: [ "must be smaller than 10 MB" ] } })
    end

    def process(file)
      ImageProcessing::MiniMagick.source(file.tempfile.path)
        .auto_orient.strip.resize_to_limit(MAX_SIDE, MAX_SIDE)
        .convert("jpg").saver(quality: 82, interlace: "Plane").call
    rescue ImageProcessing::Error, MiniMagick::Error
      raise ApplicationError.new(:validation_failed, details: { field_errors: { file: [ "could not be read as a photo. Try a JPEG." ] } })
    end
  end
end
