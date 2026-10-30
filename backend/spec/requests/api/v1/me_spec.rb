require "rails_helper"

RSpec.describe "Authenticating API calls", type: :request do
  let(:user) { create(:user, :worker) }

  it "rejects expired access tokens" do
    headers = auth_headers_for(user)
    travel_to(16.minutes.from_now) { get "/api/v1/me", headers: }
    expect(error_code).to eq("token_expired")
  end

  it "rejects tampered tokens" do
    token = Identity::Sessions.start(user:, scope: "consumer").access_token
    header, payload, sig = token.split(".")
    forged = JSON.parse(Base64.urlsafe_decode64(payload)).merge("role" => "admin")
    get "/api/v1/me", headers: json_headers("Authorization" => "Bearer #{header}.#{Base64.urlsafe_encode64(forged.to_json, padding: false)}.#{sig}")
    expect(error_code).to eq("invalid_token")
  end

  it "rejects MFA tokens as access tokens" do
    get "/api/v1/me", headers: json_headers("Authorization" => "Bearer #{Identity::Tokens.mfa_token(user:)}")
    expect(error_code).to eq("invalid_token")
  end

  it "blocks suspended users immediately" do
    headers = auth_headers_for(user)
    user.update!(status: "suspended")
    get "/api/v1/me", headers: headers
    expect(error_code).to eq("account_suspended")
  end

  it "drops a token whose role was revoked" do
    headers = auth_headers_for(user, role: "worker")
    user.user_roles.where(role: "worker").destroy_all
    get "/api/v1/me", headers: headers
    expect(error_code).to eq("role_revoked")
  end

  it "marks responses as not cacheable" do
    get "/api/v1/me", headers: auth_headers_for(user)
    expect(response.headers["Cache-Control"]).to eq("no-store")
  end

  it "ignores attempts to change protected attributes" do
    patch "/api/v1/me", params: { user: { name: "A", phone_e164: "+919999999999", status: "suspended" } }.to_json,
                        headers: auth_headers_for(user)
    expect(user.reload).to have_attributes(name: "A", phone_e164: user.phone_e164, status: "active")
  end

  it "returns JSON 404s with the standard error shape" do
    get "/api/v1/nope", headers: json_headers
    expect(response).to have_http_status(:not_found)
    expect(json["error"]).to include("code" => "route_not_found", "request_id" => be_present)
  end
end
