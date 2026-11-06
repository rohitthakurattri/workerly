module Api
  module V1
    module Customer
      class VoiceNotesController < BaseController
        # POST /api/v1/customer/service_requests/:service_request_id/voice_note (multipart: file, duration_ms)
        # Replaces any earlier voice note. Transcription runs in the background: poll the request
        # until voice_note.transcript_status is no longer "pending". Delete it like a photo
        # (DELETE …/attachments/:id).
        def create
          service_request = find_request
          authorize service_request, :update?
          note = Requests::AddVoiceNote.call(request: service_request, file: params.require(:file), duration_ms: params[:duration_ms])
          render_data(VoiceNoteResource.new(note).to_h, status: :created)
        end
      end
    end
  end
end
