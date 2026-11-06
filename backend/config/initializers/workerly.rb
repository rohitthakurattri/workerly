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
                      :ai_adapter, :ai_triage_enabled, :ai_triage_model, :ai_transcribe_enabled, :ai_transcribe_model, :ai_user_daily_limit, :ai_global_daily_limit,
                      :request_ttl_hours, :match_fanout, :max_quotes_per_request, :lead_sms_fallback,
                      :vapid_public_key, :vapid_private_key, :vapid_subject,
                      :inspection_fee_adjusted, :booking_contact_hours, :review_window_days, :dispute_window_days,
                      :payment_adapter, :razorpay_key_id, :razorpay_key_secret, :razorpay_webhook_secret,
                      :invoice_prefix, :deploy_env, keyword_init: true)

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
      # Voice notes are transcribed in the background (Phase 8). Same rule as triage: on in dev/test, off in production until a model is chosen.
      ai_transcribe_enabled: ENV.fetch("AI_TRANSCRIBE_ENABLED", Rails.env.production? ? "false" : "true") == "true",
      ai_transcribe_model: ENV["AI_TRANSCRIBE_MODEL"],
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
      dispute_window_days: ENV.fetch("DISPUTE_WINDOW_DAYS", "7").to_i,
      # Payments (D3 pending): "fake" until Razorpay keys exist; production refuses to boot without them.
      payment_adapter: ENV.fetch("PAYMENT_ADAPTER", "fake"),
      razorpay_key_id: ENV["RAZORPAY_KEY_ID"].presence,
      razorpay_key_secret: secret("RAZORPAY_KEY_SECRET"),
      razorpay_webhook_secret: secret("RAZORPAY_WEBHOOK_SECRET"),
      invoice_prefix: ENV.fetch("INVOICE_PREFIX", "WK"),
      # Which deployment this is: development, test, staging or production. Staging runs with
      # RAILS_ENV=production but may use the fake SMS and payment adapters (see below).
      deploy_env: ENV.fetch("DEPLOY_ENV", Rails.env.to_s)
    ).freeze
  end
end

Rails.application.config.active_record.encryption.tap do |enc|
  enc.primary_key = Workerly.secret("AR_ENCRYPTION_PRIMARY_KEY")
  enc.deterministic_key = Workerly.secret("AR_ENCRYPTION_DETERMINISTIC_KEY")
  enc.key_derivation_salt = Workerly.secret("AR_ENCRYPTION_KEY_DERIVATION_SALT")
end

# A real deployment must not run on stand-ins: fake payments would let orders sit unpaid forever
# and fake SMS would drop every login code. Staging may opt in (DEPLOY_ENV=staging).
module Workerly
  def self.check_deployment!(config = self.config, production: Rails.env.production?, env: ENV)
    real_production = production && config.deploy_env != "staging"
    check_razorpay_keys!(config, real_production)
    return unless real_production

    fakes = { "SMS_ADAPTER" => config.sms_adapter, "PAYMENT_ADAPTER" => config.payment_adapter }.select { |_, v| v == "fake" }
    raise "Refusing to boot production with fake adapters: #{fakes.keys.join(', ')} (set real ones, or DEPLOY_ENV=staging)" if fakes.any?
    return unless config.sms_adapter == "msg91"

    raise "SMS_ADAPTER=msg91 needs MSG91_AUTH_KEY" if env["MSG91_AUTH_KEY"].blank?
    missing = Adapters::Sms::Msg91.missing_templates(env)
    raise "SMS_ADAPTER=msg91 needs a template id for every SMS: #{missing.map { |k| Adapters::Sms::Msg91.template_env(k) }.join(', ')}" if missing.any?
  end

  # Real money only in production, and only real money there: live keys (rzp_live_) anywhere else
  # would charge real cards while testing; test keys (rzp_test_) in production would take nothing.
  def self.check_razorpay_keys!(config, real_production)
    return unless config.payment_adapter == "razorpay"

    key = config.razorpay_key_id.to_s
    raise "PAYMENT_ADAPTER=razorpay needs RAZORPAY_KEY_ID" if key.empty?
    raise "Production needs live Razorpay keys (rzp_live_…), got a test key" if real_production && !key.start_with?("rzp_live_")
    raise "Refusing live Razorpay keys outside production (#{config.deploy_env}): use test keys (rzp_test_…)" if !real_production && key.start_with?("rzp_live_")
  end
end

Rails.application.config.after_initialize { Workerly.check_deployment! }
