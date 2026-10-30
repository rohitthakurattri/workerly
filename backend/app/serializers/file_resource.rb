# Private files are exposed only as short-lived signed URLs (5 min, see application.rb).
module FileResource
  module_function

  def call(attachment)
    return nil unless attachment&.attached?

    blob = attachment.blob
    { url: blob.url(disposition: :inline), content_type: blob.content_type, byte_size: blob.byte_size,
      filename: blob.filename.to_s, expires_in: ActiveStorage.service_urls_expire_in.to_i }
  end
end
