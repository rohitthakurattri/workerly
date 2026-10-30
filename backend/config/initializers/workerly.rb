# Runtime settings read once at boot. Production values come from Secrets Manager / SSM via ENV.
module Workerly
  def self.secret(name)
    ENV.fetch(name) do
      raise KeyError, "#{name} must be set" if Rails.env.production?
      # Stable, non-secret fallback so development and test boot without a .env file.
      OpenSSL::HMAC.hexdigest("SHA256", "workerly-#{Rails.env}", name)
    end
  end

  Config = Struct.new(:jwt_secret, :otp_pepper, :token_pepper, :sms_adapter, :secure_cookies, keyword_init: true)

  def self.config
    @config ||= Config.new(
      jwt_secret: secret("JWT_SECRET"),
      otp_pepper: secret("OTP_PEPPER"),
      token_pepper: secret("TOKEN_PEPPER"),
      sms_adapter: ENV.fetch("SMS_ADAPTER", "fake"),
      secure_cookies: Rails.env.production?
    ).freeze
  end
end

Rails.application.config.active_record.encryption.tap do |enc|
  enc.primary_key = Workerly.secret("AR_ENCRYPTION_PRIMARY_KEY")
  enc.deterministic_key = Workerly.secret("AR_ENCRYPTION_DETERMINISTIC_KEY")
  enc.key_derivation_salt = Workerly.secret("AR_ENCRYPTION_KEY_DERIVATION_SALT")
end
