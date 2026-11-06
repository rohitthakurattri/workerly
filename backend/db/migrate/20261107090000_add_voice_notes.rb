# Phase 8: one voice note per request (kind "audio"), transcribed in the background.
class AddVoiceNotes < ActiveRecord::Migration[8.1]
  def change
    change_table :request_attachments, bulk: true do |t|
      t.string :transcript_status
      t.string :transcript_language, limit: 8
      t.integer :duration_ms
      t.references :transcription_analysis, foreign_key: { to_table: :ai_analyses }, index: false
    end
    add_check_constraint :request_attachments, "transcript_status IS NULL OR transcript_status IN ('pending', 'succeeded', 'failed', 'skipped')",
                         name: "request_attachments_transcript_status_check"
    add_check_constraint :request_attachments, "duration_ms IS NULL OR (duration_ms >= 0 AND duration_ms <= 600000)",
                         name: "request_attachments_duration_check"
    # At most one voice note per request.
    add_index :request_attachments, :service_request_id, unique: true, where: "kind = 'audio'", name: "index_request_attachments_one_voice_note"
  end
end
