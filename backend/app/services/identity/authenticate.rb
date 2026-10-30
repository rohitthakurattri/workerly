module Identity
  # Resolves an access token to its live session. Checking the session on every call
  # means logout, reuse detection and suspension take effect immediately, not after 15 min.
  module Authenticate
    Current = Data.define(:user, :session, :role)

    module_function

    def call(access_token)
      raise ApplicationError.unauthorized(:missing_token) if access_token.blank?

      claims = Tokens.decode(access_token, typ: "access")
      session = UserSession.includes(user: :user_roles).find_by(public_id: claims["sid"])
      raise ApplicationError.unauthorized(:session_expired) unless session&.active?

      user = session.user
      raise ApplicationError.unauthorized(:invalid_token) unless user.public_id == claims["sub"]
      raise ApplicationError.forbidden(:account_suspended) unless user.active?
      raise ApplicationError.unauthorized(:role_revoked) unless user.roles_for_scope(session.scope).include?(claims["role"])

      Current.new(user:, session:, role: claims["role"])
    end
  end
end
