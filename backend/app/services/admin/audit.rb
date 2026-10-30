module Admin
  # Writes the append-only audit row for a staff mutation. Call inside the same
  # transaction as the change so the log and the data can't disagree.
  module Audit
    module_function

    def record!(action:, target:, changes: {}, reason: nil, auth: Current.auth)
      raise ArgumentError, "audit needs a staff actor" unless auth&.session&.staff?

      AdminAction.create!(
        admin: auth.user, admin_role: auth.role, action:, reason:,
        target_type: target.class.name, target_id: target.id, changes_made: changes,
        ip: Current.ip, user_agent: Current.user_agent&.truncate(255), request_id: Current.request_id
      )
    end
  end
end
