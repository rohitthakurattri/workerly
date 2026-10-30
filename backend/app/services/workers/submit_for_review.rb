module Workers
  module SubmitForReview
    module_function

    def call(profile:)
      WorkerProfile.transaction do
        profile.lock!
        unless profile.editable?
          raise ApplicationError.new(:invalid_transition, status: :conflict,
                                     details: { from: profile.verification_status, to: "pending_review" })
        end

        missing = Requirements.missing(profile)
        raise ApplicationError.new(:profile_incomplete, details: { missing: }) if missing.any?

        profile.update!(verification_status: "pending_review", submitted_at: Time.current)
      end
      profile
    end
  end
end
