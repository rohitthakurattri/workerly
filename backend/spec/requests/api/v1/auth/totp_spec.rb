require "rails_helper"

RSpec.describe "Staff TOTP", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:totp) { ROTP::TOTP.new(admin.totp_secret) }

  def submit(code, mfa_token: Identity::Tokens.mfa_token(user: admin), **extra)
    post_json("/api/v1/auth/totp", { mfa_token:, code: }.merge(extra))
  end

  it "starts an 8-hour staff session with its own cookie" do
    freeze_time do
      submit(totp.now)
      expect(response).to have_http_status(:created)
      expect(refresh_cookie("wk_rt_staff")).to be_present
      expect(refresh_cookie("wk_rt")).to be_nil
      expect(UserSession.last).to have_attributes(scope: "staff", expires_at: 8.hours.from_now, mfa_verified_at: Time.current)
    end
  end

  it "rejects a code that was already used" do
    code = totp.now
    submit(code)
    submit(code)
    expect(response).to have_http_status(:unauthorized)
    expect(error_code).to eq("totp_incorrect")
  end

  it "rejects an expired MFA token" do
    token = Identity::Tokens.mfa_token(user: admin)
    travel_to(6.minutes.from_now) { submit(totp.now, mfa_token: token) }
    expect(error_code).to eq("token_expired")
  end

  it "does not accept an access token in place of an MFA token" do
    access = Identity::Sessions.start(user: admin, scope: "consumer").access_token
    submit(totp.now, mfa_token: access)
    expect(error_code).to eq("invalid_token")
  end

  it "refuses staff without TOTP set up" do
    user = create(:user)
    user.grant_role!(:support)
    submit("123456", mfa_token: Identity::Tokens.mfa_token(user:))
    expect(error_code).to eq("totp_not_configured")
  end

  it "refuses users whose staff role was removed after OTP" do
    token = Identity::Tokens.mfa_token(user: admin)
    admin.user_roles.where(role: "admin").destroy_all
    submit(totp.now, mfa_token: token)
    expect(response).to have_http_status(:unauthorized)
  end

  it "starts in the requested staff role when held" do
    admin.grant_role!(:finance)
    submit(totp.now, role: "finance")
    expect(json.dig("data", "active_role")).to eq("finance")
  end
end
