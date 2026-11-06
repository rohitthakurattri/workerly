# A request's voice note. params:
#   redact: true  -> contact details masked in the transcript (workers who aren't booked)
#   audio:  false -> no recording, only the transcript (a voice can carry a phone number that
#                    no redaction can remove, so unbooked workers never get the audio)
class VoiceNoteResource
  include Alba::Resource

  attribute(:id) { |a| a.public_id }
  attributes :duration_ms, :transcript_status, :transcript_language
  attribute(:transcript) { |a| params[:redact] && a.transcript ? Shared::Redact.call(a.transcript) : a.transcript }
  attribute(:file) { |a| params[:audio] == false ? nil : FileResource.call(a.file) }
  attribute(:created_at) { |a| a.created_at.iso8601 }
end
