# Runtime settings read once at boot. Production values come from Secrets Manager / SSM via ENV.
module Workerly
  def self.secret(name)
    ENV.fetch(name) do
      raise KeyError, "#{name} must be set" if Rails.env.production?
      # Stable, non-secret fallback so development and test boot without a .env file.
      OpenSSL::HMAC.hexdigest("SHA256", "workerly-#{Rails.env}", name)
    end
  end

  Config = Struct.new(:jwt_secret, :otp_pepper, :token_pepper, :sms_adapter, :secure_cookies,
                      :ai_adapter, :ai_triage_enabled, :ai_triage_model, :ai_user_daily_limit, :ai_global_daily_limit,
                      :request_ttl_hours, :match_fanout, :max_quotes_per_request, :lead_sms_fallback,
                      :vapid_public_key, :vapid_private_key, :vapid_subject,
                      :inspection_fee_adjusted, :booking_contact_hours, :review_window_days, :dispute_window_days,
                      keyword_init: true)

  def self.config
    @config ||= Config.new(
      jwt_secret: secret("JWT_SECRET"),
      otp_pepper: secret("OTP_PEPPER"),
      token_pepper: secret("TOKEN_PEPPER"),
      sms_adapter: ENV.fetch("SMS_ADAPTER", "fake"),
      secure_cookies: Rails.env.production?,
      # AI triage is behind a flag: off in production until a provider and budget are approved.
      ai_adapter: ENV.fetch("AI_ADAPTER", "fake"),
      ai_triage_enabled: ENV.fetch("AI_TRIAGE_ENABLED", Rails.env.production? ? "false" : "true") == "true",
      ai_triage_model: ENV["AI_TRIAGE_MODEL"],
      ai_user_daily_limit: ENV.fetch("AI_USER_DAILY_LIMIT", "20").to_i,
      ai_global_daily_limit: ENV.fetch("AI_GLOBAL_DAILY_LIMIT", "5000").to_i,
      # How long a submitted request stays open for quotes (D5, still pending: 24 h proposed).
      request_ttl_hours: ENV.fetch("REQUEST_TTL_HOURS", "24").to_i,
      # D5 (pending, plan defaults): invite the 10 best-ranked workers, accept at most 5 quotes.
      match_fanout: ENV.fetch("MATCH_FANOUT", "10").to_i,
      max_quotes_per_request: ENV.fetch("MAX_QUOTES_PER_REQUEST", "5").to_i,
      # A new lead is a critical event: SMS when no push subscription delivered it.
      lead_sms_fallback: ENV.fetch("LEAD_SMS_FALLBACK", "true") == "true",
      # Web push (bin/rails webpush:keys). Without keys, push is off and SMS covers critical events.
      vapid_public_key: ENV["VAPID_PUBLIC_KEY"].presence,
      vapid_private_key: ENV["VAPID_PRIVATE_KEY"].presence,
      vapid_subject: ENV.fetch("VAPID_SUBJECT", "mailto:support@workerly.in"),
      # Phase 6 policy defaults (open requirements in the plan; see docs/adr/0008):
      # the visit fee is taken off the repair bill when the customer approves the final price.
      inspection_fee_adjusted: ENV.fetch("INSPECTION_FEE_ADJUSTED", "true") == "true",
      # Contact details and chat stay open this long after completion.
      booking_contact_hours: ENV.fetch("BOOKING_CONTACT_HOURS", "48").to_i,
      review_window_days: ENV.fetch("REVIEW_WINDOW_DAYS", "30").to_i,
      dispute_window_days: ENV.fetch("DISPUTE_WINDOW_DAYS", "7").to_i
    ).freeze
  end
end

Rails.application.config.active_record.encryption.tap do |enc|
  enc.primary_key = Workerly.secret("AR_ENCRYPTION_PRIMARY_KEY")
  enc.deterministic_key = Workerly.secret("AR_ENCRYPTION_DETERMINISTIC_KEY")
  enc.key_derivation_salt = Workerly.secret("AR_ENCRYPTION_KEY_DERIVATION_SALT")
end
