module Identity
  # Issues a one-time code. Limits are enforced here against the DB (authoritative);
  # Rack::Attack adds a cheaper first line in front.
  class RequestOtp
    TTL = 5.minutes
    RESEND_AFTER = 30.seconds
    WINDOW = 15.minutes
    MAX_PER_WINDOW = 3

    Result = Data.define(:phone, :expires_in, :resend_after)

    def self.call(...) = new(...).call

    def initialize(phone:, ip: nil, user_agent: nil)
      @phone = PhoneNumber.normalize!(phone)
      @ip = ip
      @user_agent = user_agent
    end

    def call
      code = nil
      OtpChallenge.transaction do
        # Serialise concurrent requests for the same phone.
        OtpChallenge.connection.execute(
          OtpChallenge.sanitize_sql([ "SELECT pg_advisory_xact_lock(hashtext(?))", "otp:#{@phone}" ])
        )
        enforce_limits!
        OtpChallenge.for_phone(@phone).pending.update_all(invalidated_at: Time.current)
        code = format("%06d", SecureRandom.random_number(1_000_000))
        OtpChallenge.create!(phone_e164: @phone, code_digest: self.class.digest(@phone, code),
                             expires_at: TTL.from_now, ip: @ip, user_agent: @user_agent&.truncate(255))
      end
      SendOtpSmsJob.perform_later(@phone, code)
      Result.new(phone: PhoneNumber.mask(@phone), expires_in: TTL.to_i, resend_after: RESEND_AFTER.to_i)
    end

    def self.digest(phone, code) = OpenSSL::HMAC.hexdigest("SHA256", Workerly.config.otp_pepper, "#{phone}:#{code}")

    private

    def enforce_limits!
      recent = OtpChallenge.for_phone(@phone).where(created_at: WINDOW.ago..)
      last = recent.maximum(:created_at)
      if last && last > RESEND_AFTER.ago
        raise ApplicationError.too_many_requests(:otp_resend_too_soon, details: { retry_after: (last + RESEND_AFTER - Time.current).ceil })
      end
      if recent.count >= MAX_PER_WINDOW
        oldest = recent.order(:created_at).first.created_at
        raise ApplicationError.too_many_requests(:otp_limit_reached, details: { retry_after: (oldest + WINDOW - Time.current).ceil })
      end
    end
  end
end
