module Admin
  module SuspendWorker
    module_function

    def suspend(profile:, reason:, auth: Current.auth)
      raise ApplicationError.new(:reason_required, details: { field_errors: { reason: [ "is required" ] } }) if reason.blank?

      change(profile, auth) do
        raise ApplicationError.new(:already_suspended, status: :conflict) if profile.suspended?

        profile.update!(suspended_at: Time.current, suspension_reason: reason, available: false)
        [ "suspended", reason ]
      end
    end

    def reinstate(profile:, reason: nil, auth: Current.auth)
      change(profile, auth) do
        raise ApplicationError.new(:not_suspended, status: :conflict) unless profile.suspended?

        profile.update!(suspended_at: nil, suspension_reason: nil)
        [ "reinstated", reason ]
      end
    end

    def change(profile, auth)
      WorkerProfile.transaction do
        profile.lock!
        decision, reason = yield
        WorkerVerification.create!(worker_profile: profile, admin: auth.user, decision:, reason:)
        Audit.record!(action: "worker.#{decision}", target: profile, reason:, auth:,
                      changes: { suspended_at: profile.saved_changes["suspended_at"] }.compact)
      end
      profile
    end
  end
end
