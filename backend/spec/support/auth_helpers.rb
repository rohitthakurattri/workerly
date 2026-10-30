module AuthHelpers
  ORIGIN = "http://localhost:3001"

  def json = JSON.parse(response.body)
  def error_code = json.dig("error", "code")

  def json_headers(extra = {})
    { "Content-Type" => "application/json", "Accept" => "application/json", "Origin" => ORIGIN }.merge(extra)
  end

  def post_json(path, body = {}, headers: {})
    post path, params: body.to_json, headers: json_headers(headers)
  end

  # Starts a session directly (bypassing OTP) and returns auth headers.
  def auth_headers_for(user, scope: "consumer", role: nil)
    issued = Identity::Sessions.start(user:, scope:, role:, mfa: scope == "staff")
    json_headers("Authorization" => "Bearer #{issued.access_token}")
  end

  # Runs the real OTP flow and returns the code that was "sent".
  def request_otp_code(phone)
    perform_enqueued_jobs { Identity::RequestOtp.call(phone:) }
    Adapters::Sms::Fake.deliveries.last.body[/\A(\d{6})/, 1]
  end

  def refresh_cookie(name = "wk_rt")
    cookie = Array(response.headers["Set-Cookie"]).join("\n").split("\n").find { |c| c.start_with?("#{name}=") }
    cookie && cookie[/\A#{name}=([^;]*)/, 1]
  end
end

RSpec.configure { |c| c.include AuthHelpers, type: :request }
