require "rails_helper"

# Phase 2 exit gate: only approved, unsuspended workers reach lead endpoints.
RSpec.describe "Worker lead gate", type: :request do
  def get_leads(headers)
    get("/api/v1/worker/leads", headers:)
    [ response.status, error_code ]
  end

  {
    "draft" => [ {}, "worker_not_verified" ],
    "pending_review" => [ { verification_status: "pending_review" }, "worker_not_verified" ],
    "changes_requested" => [ { verification_status: "changes_requested" }, "worker_not_verified" ],
    "rejected" => [ { verification_status: "rejected" }, "worker_not_verified" ]
  }.each do |state, (attrs, code)|
    it "returns 403 #{code} for a #{state} worker on every lead endpoint" do
      profile = create(:worker_profile, **attrs)
      headers = auth_headers_for(profile.user, role: "worker")

      expect(get_leads(headers)).to eq([ 403, code ])
      get "/api/v1/worker/leads/#{SecureRandom.uuid}", headers: headers
      expect([ response.status, error_code ]).to eq([ 403, code ])
    end
  end

  it "returns 403 for an approved but suspended worker" do
    profile = create(:worker_profile, :approved)
    profile.update!(suspended_at: Time.current, suspension_reason: "complaints")
    expect(get_leads(auth_headers_for(profile.user, role: "worker"))).to eq([ 403, "worker_suspended" ])
  end

  it "returns 403 for a worker whose account is suspended" do
    profile = create(:worker_profile, :approved)
    headers = auth_headers_for(profile.user, role: "worker")
    profile.user.update!(status: "suspended")
    expect(get_leads(headers)).to eq([ 403, "account_suspended" ])
  end

  it "returns 403 when acting as a customer, even for an approved worker" do
    profile = create(:worker_profile, :approved)
    expect(get_leads(auth_headers_for(profile.user, role: "customer"))).to eq([ 403, "role_required" ])
  end

  it "returns 403 for a worker-role user without a profile" do
    expect(get_leads(auth_headers_for(create(:user, :worker), role: "worker"))).to eq([ 403, "worker_not_registered" ])
  end

  it "returns 401 without a token" do
    expect(get_leads(json_headers)).to eq([ 401, "missing_token" ])
  end

  it "lets an approved worker in" do
    profile = create(:worker_profile, :approved)
    get "/api/v1/worker/leads", headers: auth_headers_for(profile.user, role: "worker")
    expect(response).to have_http_status(:ok)
    expect(json["data"]).to eq([])
  end

  it "only lets approved workers switch on availability" do
    draft = create(:worker_profile)
    patch "/api/v1/worker/availability", params: { available: true }.to_json, headers: auth_headers_for(draft.user, role: "worker")
    expect(error_code).to eq("worker_not_verified")

    approved = create(:worker_profile, :approved)
    patch "/api/v1/worker/availability", params: { available: true }.to_json, headers: auth_headers_for(approved.user, role: "worker")
    expect(json.dig("data", "available")).to be(true)
  end

  it "enforces 'available only when approved' in the database too" do
    profile = create(:worker_profile)
    expect { profile.update_columns(available: true) }.to raise_error(ActiveRecord::StatementInvalid, /worker_profiles_available_check/)
  end
end
