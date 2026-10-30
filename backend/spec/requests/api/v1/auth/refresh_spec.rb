require "rails_helper"

RSpec.describe "Refreshing a session", type: :request do
  let(:user) { create(:user, :worker) }
  let!(:issued) { Identity::Sessions.start(user:, scope: "consumer") }

  def refresh_with_cookie(raw, name: "wk_rt", origin: AuthHelpers::ORIGIN, **body)
    cookies[name] = raw
    post "/api/v1/auth/refresh", params: body.to_json, headers: json_headers("Origin" => origin)
  end

  it "rotates the cookie and returns a new access token" do
    refresh_with_cookie(issued.refresh_token)

    expect(response).to have_http_status(:ok)
    expect(refresh_cookie).to be_present.and(satisfy { |c| c != issued.refresh_token })
    expect(json.dig("data", "access_token")).to be_present
  end

  it "keeps the session's role choice per call" do
    refresh_with_cookie(issued.refresh_token, role: "worker")
    expect(json.dig("data", "active_role")).to eq("worker")
  end

  it "treats a parallel refresh within 15 s as another tab, not theft" do
    refresh_with_cookie(issued.refresh_token)
    new_token = refresh_cookie

    travel_to(10.seconds.from_now) { refresh_with_cookie(issued.refresh_token) }
    expect(response).to have_http_status(:ok)
    expect(refresh_cookie).to be_nil # the other tab already holds the new cookie
    expect(issued.session.reload).to be_active

    refresh_with_cookie(new_token)
    expect(response).to have_http_status(:ok)
  end

  it "revokes the whole session when an old token is replayed later" do
    refresh_with_cookie(issued.refresh_token)
    new_token = refresh_cookie

    travel_to(1.minute.from_now) do
      refresh_with_cookie(issued.refresh_token)
      expect(error_code).to eq("refresh_token_reused")
      expect(issued.session.reload.revoke_reason).to eq("refresh_token_reused")

      refresh_with_cookie(new_token)
      expect(error_code).to eq("session_expired")

      get "/api/v1/me", headers: json_headers("Authorization" => "Bearer #{issued.access_token}")
      expect(response).to have_http_status(:unauthorized)
    end
  end

  it "rejects cookie refreshes from foreign origins" do
    refresh_with_cookie(issued.refresh_token, origin: "https://evil.example")
    expect(response).to have_http_status(:forbidden)
    expect(error_code).to eq("origin_not_allowed")
  end

  it "rejects a missing cookie and clears it" do
    post_json("/api/v1/auth/refresh")
    expect(error_code).to eq("invalid_refresh_token")
  end

  it "never extends past the session's absolute lifetime" do
    travel_to(181.days.from_now) { refresh_with_cookie(issued.refresh_token) }
    expect(error_code).to eq("session_expired")
  end

  it "expires an unused refresh token after 30 days" do
    travel_to(31.days.from_now) { refresh_with_cookie(issued.refresh_token) }
    expect(error_code).to eq("session_expired")
  end

  it "stops suspended users" do
    user.update!(status: "suspended")
    refresh_with_cookie(issued.refresh_token)
    expect(error_code).to eq("account_suspended")
  end

  it "uses the staff cookie for staff sessions and caps them at 8 hours" do
    admin = create(:user, :admin)
    staff = Identity::Sessions.start(user: admin, scope: "staff", mfa: true)

    refresh_with_cookie(staff.refresh_token, name: "wk_rt_staff", scope: "staff")
    expect(response).to have_http_status(:ok)
    expect(refresh_cookie("wk_rt_staff")).to be_present

    travel_to(8.hours.from_now + 1.minute) do
      refresh_with_cookie(refresh_cookie("wk_rt_staff"), name: "wk_rt_staff", scope: "staff")
      expect(error_code).to eq("session_expired")
    end
  end

  it "does not read the consumer cookie for a staff refresh" do
    refresh_with_cookie(issued.refresh_token, scope: "staff")
    expect(error_code).to eq("invalid_refresh_token")
  end
end
