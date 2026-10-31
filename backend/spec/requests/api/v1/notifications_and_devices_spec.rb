require "rails_helper"

RSpec.describe "Cable tickets, devices and notifications", type: :request do
  let(:user) { create(:user) }
  let(:headers) { auth_headers_for(user) }
  let(:subscription) { { endpoint: "https://fcm.googleapis.com/fcm/send/abc", keys: { p256dh: "BNc…key", auth: "auth…" } } }

  it "issues a one-minute cable ticket" do
    post("/api/v1/cable_tickets", headers:)
    expect(json["data"]).to include("url" => "ws://localhost:3000/cable", "expires_in" => 60)
    expect(Identity::Tokens.decode(json.dig("data", "ticket"), typ: "cable")).to include("role" => "customer")
  end

  it "says whether push is set up" do
    with_config(vapid_public_key: "pub", vapid_private_key: "priv")
    get("/api/v1/devices/push_config", headers:)
    expect(json["data"]).to eq("enabled" => true, "public_key" => "pub")
  end

  it "saves a subscription for the active app, and moves a shared browser to the new user" do
    post("/api/v1/devices", params: subscription.to_json, headers:)
    expect(json.dig("data", "app")).to eq("customer")
    expect(user.device_subscriptions.sole.p256dh).to eq("BNc…key") # encrypted at rest

    other = create(:user)
    post("/api/v1/devices", params: subscription.to_json, headers: auth_headers_for(other))
    expect(DeviceSubscription.sole.user).to eq(other)
  end

  it "accepts only real push services (the server calls the endpoint) and refuses staff sessions" do
    %w[http://fcm.googleapis.com/x https://169.254.169.254/latest https://evil.test/x https://fcm.googleapis.com.evil.test/x
       https://fcm.googleapis.com:8443/x https://user@fcm.googleapis.com/x].each do |endpoint|
      post("/api/v1/devices", params: subscription.merge(endpoint:).to_json, headers:)
      expect(json.dig("error", "details", "field_errors")).to have_key("endpoint"), endpoint
    end
    %w[https://updates.push.services.mozilla.com/wpush/v2/x https://web.push.apple.com/QG4x https://wns2-bl2p.notify.windows.com/w/?token=x].each do |endpoint|
      post("/api/v1/devices", params: subscription.merge(endpoint:).to_json, headers:)
      expect(response).to have_http_status(:created), endpoint
    end
    admin = create(:user, :admin)
    post("/api/v1/devices", params: subscription.to_json, headers: staff_headers_for(admin, role: "admin"))
    expect(error_code).to eq("consumer_session_required")
  end

  it "removes a subscription on logout" do
    post("/api/v1/devices", params: subscription.to_json, headers:)
    delete("/api/v1/devices", params: { endpoint: subscription[:endpoint] }.to_json, headers:)
    expect(DeviceSubscription.count).to eq(0)
  end

  it "lists notifications newest first and marks them read" do
    first = user.notifications.create!(kind: "lead.new", title: "One")
    user.notifications.create!(kind: "lead.new", title: "Two")
    create(:user).notifications.create!(kind: "lead.new", title: "Not mine")
    get("/api/v1/notifications", headers:)
    expect(json["data"].map { |n| n["title"] }).to eq(%w[Two One])
    expect(json.dig("meta", "unread")).to eq(2)

    post("/api/v1/notifications/#{first.public_id}/read", headers:)
    post("/api/v1/notifications/read_all", headers:)
    expect(user.notifications.unread.count).to eq(0)
  end
end
