module Requests
  # Daily: drafts nobody touched for 30 days are deleted with their photos.
  class PurgeStaleDraftsJob < ApplicationJob
    queue_as :low

    MAX_AGE = 30.days

    def perform(now: Time.current)
      ServiceRequest.where(status: "draft").where(updated_at: ...(now - MAX_AGE)).find_each do |draft|
        draft.attachments.each { |a| a.file.purge_later }
        draft.update_columns(triage_analysis_id: nil)
        AiAnalysis.where(analysable: draft).delete_all # append-only in the app; the draft's own log goes with it
        draft.destroy!
      end
    end
  end
end
