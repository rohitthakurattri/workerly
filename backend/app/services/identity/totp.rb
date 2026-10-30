module Identity
  # TOTP second factor for staff. Secrets are provisioned out of band
  # (bin/rails "admin:grant[...]"), never through the API.
  module Totp
    ISSUER = "Workerly"

    module_function

    def provision!(user)
      user.update!(totp_secret: ROTP::Base32.random, totp_enabled_at: Time.current, totp_last_step: nil)
      ROTP::TOTP.new(user.totp_secret, issuer: ISSUER).provisioning_uri(user.phone_e164)
    end

    # Accepts the current code or the previous one (30 s drift) and rejects reuse.
    def verify!(user, code)
      raise ApplicationError.forbidden(:totp_not_configured) unless user.totp_enabled?

      User.transaction do
        user.lock!
        totp = ROTP::TOTP.new(user.totp_secret, issuer: ISSUER)
        after = user.totp_last_step && user.totp_last_step * totp.interval
        accepted_at = totp.verify(code.to_s.strip, drift_behind: 30, after:)
        raise ApplicationError.unauthorized(:totp_incorrect) unless accepted_at

        user.update!(totp_last_step: accepted_at / totp.interval)
      end
    end
  end
end
