module Requests
  # Daily: drafts nobody touched for 30 days are deleted with their photos, voice note and AI log.
  class PurgeStaleDraftsJob < ApplicationJob
    queue_as :low

    MAX_AGE = 30.days

    def perform(now: Time.current)
      ServiceRequest.where(status: "draft").where(updated_at: ...(now - MAX_AGE)).find_each do |draft|
        draft.attachments.each { |a| a.file.purge_later }
        ServiceRequest.transaction do
          draft.update_columns(triage_analysis_id: nil)
          draft.attachments.update_all(transcription_analysis_id: nil)
          # The AI log is append-only, but an abandoned draft's own log (it holds the description) goes with it.
          AppendOnly.rewriting { AiAnalysis.where(analysable: draft).delete_all }
          draft.destroy!
        end
      end
    end
  end
end
