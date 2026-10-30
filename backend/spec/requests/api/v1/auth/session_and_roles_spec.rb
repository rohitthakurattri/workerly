require "rails_helper"

RSpec.describe "Logout and role switching", type: :request do
  describe "DELETE /api/v1/auth/session" do
    it "revokes the session so the access token and refresh token stop working" do
      user = create(:user)
      issued = Identity::Sessions.start(user:, scope: "consumer")
      headers = json_headers("Authorization" => "Bearer #{issued.access_token}")
      cookies["wk_rt"] = issued.refresh_token

      delete "/api/v1/auth/session", headers: headers
      expect(response).to have_http_status(:no_content)
      expect(Array(response.headers["Set-Cookie"]).join).to match(/wk_rt=;/)

      get "/api/v1/me", headers: headers
      expect(error_code).to eq("session_expired")

      post_json("/api/v1/auth/refresh", { token_delivery: "body", refresh_token: issued.refresh_token })
      expect(error_code).to eq("session_expired")
    end

    it "leaves the user's other sessions alone" do
      user = create(:user)
      phone = Identity::Sessions.start(user:, scope: "consumer")
      laptop = Identity::Sessions.start(user:, scope: "consumer")

      delete "/api/v1/auth/session", headers: json_headers("Authorization" => "Bearer #{phone.access_token}")
      get "/api/v1/me", headers: json_headers("Authorization" => "Bearer #{laptop.access_token}")
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /api/v1/auth/switch_role" do
    it "switches customer -> worker and back without a new session" do
      user = create(:user, :worker)
      headers = auth_headers_for(user)

      expect { post "/api/v1/auth/switch_role", params: { role: "worker" }.to_json, headers: }.not_to change(UserSession, :count)
      worker_token = json.dig("data", "access_token")

      get "/api/v1/me", headers: json_headers("Authorization" => "Bearer #{worker_token}")
      expect(json.dig("data", "active_role")).to eq("worker")
      expect(refresh_cookie).to be_nil
    end

    it "does not let a consumer session take a staff role, even if the user holds it" do
      user = create(:user, :admin)
      post "/api/v1/auth/switch_role", params: { role: "admin" }.to_json, headers: auth_headers_for(user)
      expect(error_code).to eq("role_not_granted")
    end

    it "switches between staff roles in a staff session" do
      user = create(:user, :admin, :finance)
      post "/api/v1/auth/switch_role", params: { role: "finance" }.to_json, headers: auth_headers_for(user, scope: "staff")
      expect(json.dig("data", "active_role")).to eq("finance")
    end

    it "requires a role the user actually has" do
      post "/api/v1/auth/switch_role", params: { role: "worker" }.to_json, headers: auth_headers_for(create(:user))
      expect(response).to have_http_status(:forbidden)
    end

    it "requires authentication" do
      post_json("/api/v1/auth/switch_role", { role: "worker" })
      expect(error_code).to eq("missing_token")
    end
  end
end
