module Identity
  # Checks a code against the latest pending challenge and returns the verified user.
  # Consumer logins create the user (with the customer role) on first success;
  # staff logins never create users.
  class VerifyOtp
    def self.call(...) = new(...).call

    def initialize(phone:, code:, scope:)
      @phone = PhoneNumber.normalize!(phone)
      @code = code.to_s.strip
      @scope = scope
    end

    def call
      verified = OtpChallenge.transaction do
        challenge = OtpChallenge.for_phone(@phone).pending.order(created_at: :desc).lock.first
        raise ApplicationError.new(:otp_invalid_or_expired) unless challenge
        check!(challenge)
      end
      raise ApplicationError.new(:otp_incorrect, details: { attempts_left: verified }) unless verified == true

      find_or_create_user
    end

    private

    # Returns true on success, or the number of attempts left. Failed attempts are
    # committed so a wrong code still counts even though we raise afterwards.
    def check!(challenge)
      if challenge.exhausted?
        challenge.update!(invalidated_at: Time.current)
        raise ApplicationError.new(:otp_invalid_or_expired)
      end

      if /\A\d{6}\z/.match?(@code) &&
          ActiveSupport::SecurityUtils.secure_compare(challenge.code_digest, RequestOtp.digest(@phone, @code))
        challenge.update!(consumed_at: Time.current)
        return true
      end

      challenge.increment!(:attempts)
      challenge.update!(invalidated_at: Time.current) if challenge.exhausted?
      OtpChallenge::MAX_ATTEMPTS - challenge.attempts
    end

    def find_or_create_user
      user = User.kept.find_by(phone_e164: @phone)
      if @scope == "staff"
        raise ApplicationError.forbidden(:not_staff) unless user&.staff?
      end
      user ||= User.transaction do
        User.create!(phone_e164: @phone).tap { |u| u.grant_role!(:customer) }
      rescue ActiveRecord::RecordNotUnique
        User.kept.find_by!(phone_e164: @phone) # lost a race with a parallel verify
      end
      raise ApplicationError.forbidden(:account_suspended) unless user.active?

      user
    end
  end
end
