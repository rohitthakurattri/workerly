module Identity
  # Creates, rotates and revokes login sessions and their refresh tokens.
  module Sessions
    REFRESH_TTL = 30.days
    CONSUMER_MAX_AGE = 180.days
    STAFF_MAX_AGE = 8.hours
    # A rotated token presented again this soon is a parallel refresh from another tab,
    # not theft: return an access token but don't rotate again.
    ROTATION_GRACE = 15.seconds

    Issued = Data.define(:session, :access_token, :refresh_token, :role)

    module_function

    def start(user:, scope:, role: nil, ip: nil, user_agent: nil, mfa: false)
      role = pick_role!(user, scope, role)
      max_age = scope == "staff" ? STAFF_MAX_AGE : CONSUMER_MAX_AGE
      session = nil
      raw = nil
      UserSession.transaction do
        session = user.user_sessions.create!(scope:, expires_at: max_age.from_now, ip:,
                                             user_agent: user_agent&.truncate(255),
                                             mfa_verified_at: (Time.current if mfa), last_seen_at: Time.current)
        raw = issue_refresh_token(session)
        user.update_columns(last_login_at: Time.current)
      end
      Issued.new(session:, role:, refresh_token: raw, access_token: Tokens.access_token(session:, role:))
    end

    # role: nil keeps the default role for the scope.
    def refresh(raw_token:, role: nil)
      token = RefreshToken.find_by_raw(raw_token)
      raise ApplicationError.unauthorized(:invalid_refresh_token) unless token

      UserSession.transaction do
        session = UserSession.lock.find(token.user_session_id)
        token.reload
        raise ApplicationError.unauthorized(:session_expired) unless session.active?

        if token.rotated?
          if token.rotated_at > ROTATION_GRACE.ago
            role = pick_role!(session.user, session.scope, role)
            next Issued.new(session:, role:, refresh_token: nil, access_token: Tokens.access_token(session:, role:))
          end
          session.revoke!("refresh_token_reused")
          # Commit the revocation, then fail outside the transaction.
          next :reused
        end
        raise ApplicationError.unauthorized(:session_expired) if token.expired?

        user = session.user
        raise ApplicationError.forbidden(:account_suspended) unless user.active?

        role = pick_role!(user, session.scope, role)
        token.update!(rotated_at: Time.current)
        session.update!(last_seen_at: Time.current)
        Issued.new(session:, role:, refresh_token: issue_refresh_token(session),
                   access_token: Tokens.access_token(session:, role:))
      end.tap { |result| raise ApplicationError.unauthorized(:refresh_token_reused) if result == :reused }
    end

    def switch_role(session:, role:)
      role = pick_role!(session.user, session.scope, role, strict: true)
      Issued.new(session:, role:, refresh_token: nil, access_token: Tokens.access_token(session:, role:))
    end

    def pick_role!(user, scope, requested, strict: false)
      allowed = user.roles_for_scope(scope)
      if requested.present?
        return requested.to_s if allowed.include?(requested.to_s)
        raise ApplicationError.forbidden(:role_not_granted) if strict || !User::ROLES.include?(requested.to_s)
      end
      # Consumer users always hold customer; staff fall back to their highest role.
      (scope == "staff" ? User::STAFF_ROLES : User::CONSUMER_ROLES).find { |r| allowed.include?(r) } ||
        raise(ApplicationError.forbidden(:role_not_granted))
    end

    def issue_refresh_token(session)
      raw = SecureRandom.urlsafe_base64(48)
      session.refresh_tokens.create!(token_digest: RefreshToken.digest(raw),
                                     expires_at: [ REFRESH_TTL.from_now, session.expires_at ].min)
      raw
    end
  end
end
