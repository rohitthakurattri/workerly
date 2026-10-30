module Identity
  # Signed JWTs. Access tokens authorise API calls; MFA tokens bridge OTP -> TOTP for staff.
  module Tokens
    ACCESS_TTL = 15.minutes
    MFA_TTL = 5.minutes
    ISSUER = "workerly-api"
    ALGORITHM = "HS256"

    module_function

    def access_token(session:, role:)
      encode(typ: "access", sub: session.user.public_id, sid: session.public_id,
             scope: session.scope, role: role.to_s, ttl: ACCESS_TTL)
    end

    def mfa_token(user:)
      encode(typ: "mfa", sub: user.public_id, ttl: MFA_TTL)
    end

    def decode(token, typ:)
      payload, = JWT.decode(token.to_s, Workerly.config.jwt_secret, true,
                            algorithm: ALGORITHM, iss: ISSUER, verify_iss: true, required_claims: %w[exp sub typ])
      raise JWT::DecodeError, "wrong token type" unless payload["typ"] == typ

      payload
    rescue JWT::ExpiredSignature
      raise ApplicationError.unauthorized(:token_expired)
    rescue JWT::DecodeError
      raise ApplicationError.unauthorized(:invalid_token)
    end

    def encode(ttl:, **claims)
      now = Time.current.to_i
      JWT.encode(claims.merge(iss: ISSUER, iat: now, exp: now + ttl.to_i, jti: SecureRandom.uuid),
                 Workerly.config.jwt_secret, ALGORITHM)
    end
  end
end
