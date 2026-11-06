module Requests
  # Adds (or replaces) the draft's voice note and queues its transcription. The audio is kept as
  # recorded: there is no server-side transcoding (no ffmpeg on the servers), so the type is
  # sniffed from the bytes and the size capped; 3 MB is well over two minutes of Opus or AAC.
  module AddVoiceNote
    module_function

    def call(request:, file:, duration_ms: nil)
      raise ApplicationError.new(:request_locked, status: :conflict) unless request.draft?

      type = sniff(file)
      field_error!("must be a voice recording (WebM, Ogg, MP4 or MP3)") unless type
      field_error!("must be smaller than 3 MB") if file.size > RequestAttachment::VOICE_MAX_SIZE

      duration = duration_ms.presence && duration_ms.to_i.clamp(0, RequestAttachment::VOICE_MAX_MS)
      transcribe = Workerly.config.ai_transcribe_enabled
      attachment = ServiceRequest.transaction do
        request.lock!
        request.attachments.voice_notes.each do |old|
          old.file.purge_later
          old.destroy!
        end
        request.attachments.create!(
          kind: "audio", duration_ms: duration, transcript_status: transcribe ? "pending" : "skipped",
          file: { io: file.tempfile, filename: "voice-#{SecureRandom.hex(4)}.#{extension(type)}", content_type: type, identify: false }
        )
      end
      TranscribeVoiceNoteJob.perform_later(attachment.id) if transcribe
      attachment
    end

    # The bytes must match an audio/video container on their own; the file name only refines the
    # answer (Matroska -> WebM). Marcel alone would trust a renamed file's extension.
    def sniff(file)
      io = file.tempfile
      magic = Marcel::Magic.by_magic(io)&.type
      io.rewind
      return nil unless magic && (RequestAttachment::VOICE_TYPES.include?(magic) || magic == "application/x-matroska")

      type = Marcel::MimeType.for(io, name: file.original_filename)
      io.rewind
      return nil unless RequestAttachment::VOICE_TYPES.include?(type) || type == "application/x-matroska"

      # Stored as audio so browsers offer a plain audio player (the container is the same).
      { "application/x-matroska" => "audio/webm", "video/webm" => "audio/webm", "video/mp4" => "audio/mp4" }.fetch(type, type)
    end

    def field_error!(message)
      raise ApplicationError.new(:validation_failed, details: { field_errors: { file: [ message ] } })
    end

    def extension(type) = { "audio/ogg" => "ogg", "audio/mpeg" => "mp3", "audio/wav" => "wav", "audio/x-wav" => "wav" }.fetch(type) { type.include?("mp4") || type.include?("m4a") ? "m4a" : "webm" }
  end
end
