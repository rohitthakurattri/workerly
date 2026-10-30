# First-line throttles. Identity::RequestOtp enforces the authoritative per-phone limits in the DB.
class Rack::Attack
  Rack::Attack.cache.store =
    if Rails.env.production?
      ActiveSupport::Cache::RedisCacheStore.new(url: "#{ENV.fetch("REDIS_URL")}/1", namespace: "rack_attack")
    else
      ActiveSupport::Cache::MemoryStore.new
    end

  def self.json_param(req, key)
    return unless req.content_type.to_s.include?("json")

    body = req.body.read
    req.body.rewind
    JSON.parse(body)[key] if body.present?
  rescue JSON::ParserError
    nil
  end

  # Local development: every request is 127.0.0.1, so IP throttles would block normal testing.
  # Per-phone limits in Identity::RequestOtp still apply.
  safelist("development/localhost") do |req|
    Rails.env.development? && %w[127.0.0.1 ::1].include?(req.ip)
  end

  throttle("otp/phone", limit: 3, period: 15.minutes) do |req|
    if req.post? && req.path == "/api/v1/auth/otp"
      Identity::PhoneNumber.normalize(json_param(req, "phone") || req.params["phone"])
    end
  end
  throttle("otp/ip", limit: 10, period: 15.minutes) do |req|
    req.ip if req.post? && req.path == "/api/v1/auth/otp"
  end
  throttle("otp_verify/ip", limit: 20, period: 15.minutes) do |req|
    req.ip if req.post? && %w[/api/v1/auth/otp/verify /api/v1/auth/totp].include?(req.path)
  end
  throttle("api/ip", limit: 300, period: 5.minutes) do |req|
    req.ip if req.path.start_with?("/api/")
  end

  self.throttled_responder = lambda do |req|
    match = req.env["rack.attack.match_data"] || {}
    retry_after = (match[:period].to_i - (Time.now.to_i % match[:period].to_i)) if match[:period]
    body = { error: { code: "rate_limited", message: "Too many requests. Please try again later.",
                      details: { retry_after: }, request_id: req.env["action_dispatch.request_id"] } }
    [ 429, { "content-type" => "application/json", "retry-after" => retry_after.to_s }, [ body.to_json ] ]
  end
end

Rails.application.config.middleware.use Rack::Attack
