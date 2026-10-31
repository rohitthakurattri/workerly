require "rails_helper"

RSpec.describe "Admin service requests", type: :request do
  let!(:mohali) { create(:mohali) }
  let(:support) { create(:user, :support) }
  let(:headers) { staff_headers_for(support, role: "support") }

  it "lists submitted requests and flags those needing attention" do
    create(:worker_profile, :matchable)
    matched = create(:service_request, :open)
    Matching::InviteWorkers.call(matched)
    unmatched = create(:service_request, :open, service_category: create(:service_category, slug: "electrician"))
    Matching::InviteWorkers.call(unmatched) # no electricians anywhere
    create(:service_request) # drafts are private

    get("/api/v1/admin/service_requests", headers:)
    expect(json["data"].size).to eq(2)
    attention = -> { get("/api/v1/admin/service_requests?filter[attention]=true", headers: staff_headers_for(support, role: "support")) }
    attention.call
    expect(json["data"].map { |r| r["id"] }).to eq([ unmatched.public_id ])
    expect(json.dig("meta", "attention_count")).to eq(1)

    travel(31.minutes) do # still no quotes after 30 minutes
      attention.call
      expect(json["data"].map { |r| r["id"] }).to contain_exactly(matched.public_id, unmatched.public_id)
    end
  end

  it "shows who was invited and why" do
    worker = create(:worker_profile, :matchable)
    request = create(:service_request, :open)
    Matching::InviteWorkers.call(request)
    get("/api/v1/admin/service_requests/#{request.public_id}", headers:)
    expect(json.dig("data", "invitations").sole).to include("rank" => 1, "worker_id" => worker.public_id, "distance_m" => be < 100)
    expect(json.dig("data", "customer", "phone")).to eq(request.customer.phone_e164)
  end

  it "is for admin and support only" do
    verifier = create(:user, :verifier)
    get "/api/v1/admin/service_requests", headers: staff_headers_for(verifier, role: "verifier")
    expect(response).to have_http_status(:forbidden)
  end
end
