module Requests
  # Queued when a voice note is uploaded. Gone (replaced or deleted) or already done: nothing to do.
  class TranscribeVoiceNoteJob < ApplicationJob
    queue_as :default

    def perform(attachment_id)
      attachment = RequestAttachment.find_by(id: attachment_id)
      Ai::TranscribeVoiceNote.call(attachment) if attachment
    end
  end
end
