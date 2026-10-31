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

  def staff_headers_for(user, role:) = auth_headers_for(user, scope: "staff", role:)

  # Multipart requests must not carry the JSON content type.
  def multipart_headers(headers) = headers.except("Content-Type")

  def fixture(name, type) = Rack::Test::UploadedFile.new(Rails.root.join("spec/fixtures/files", name), type)

  # Staff context for calling admin services directly in specs.
  def staff_auth(user, role:)
    Identity::Authenticate::Current.new(user:, role:, session: Identity::Sessions.start(user:, scope: "staff", role:, mfa: true).session)
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

RSpec.configure do |c|
  c.include AuthHelpers, type: :request
  c.include AuthHelpers, type: :service
  c.include AuthHelpers, type: :model
  c.include AuthHelpers, type: :job
end
