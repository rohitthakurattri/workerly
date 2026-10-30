module Workers
  # Adds a document. An unreviewed document of the same kind is replaced; rejected
  # ones stay as history.
  module UploadDocument
    module_function

    def call(profile:, kind:, doc_type:, file:, number_last4: nil)
      raise ApplicationError.new(:profile_locked, status: :conflict) unless profile.editable?

      WorkerProfile.transaction do
        profile.lock!
        profile.documents.where(kind:, status: "pending").find_each do |doc|
          doc.file.purge_later
          doc.destroy!
        end
        # A changes_requested profile may replace an approved doc too; the old one is kept as superseded.
        profile.documents.where(kind:, status: "approved").update_all(status: "superseded", updated_at: Time.current)
        profile.documents.create!(kind:, doc_type:, number_last4:, file:)
      end
    end
  end
end
