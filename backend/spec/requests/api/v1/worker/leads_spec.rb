require "rails_helper"

RSpec.describe "Worker leads", type: :request do
  let!(:mohali) { create(:mohali) }
  let!(:worker) { create(:worker_profile, :matchable) }
  let(:headers) { auth_headers_for(worker.user, role: "worker") }
  let(:request_record) do
    create(:service_request, :open, description: "Tap leaking. Call me on 98765 43210 or mail me@example.com",
                                    answers: [ { "question" => "Phone?", "answer" => "+91 98765 43210" } ])
  end

  before { Matching::InviteWorkers.call(request_record) }

  it "lists invited leads with the area and a distance band, never contact details or the exact address" do
    get("/api/v1/worker/leads", headers:)
    lead = json["data"].sole
    expect(lead).to include("id" => request_record.public_id, "status" => "new", "locality" => "Sector 70", "city" => "mohali",
                            "distance_band" => "under_1km", "description" => "Tap leaking. Call me on [phone removed] or mail [email removed]")
    expect(lead["answers"]).to eq([ { "question" => "Phone?", "answer" => "[phone removed]" } ])
    expect(response.body).not_to include("House 1234", request_record.customer.phone_e164, "98765")
  end

  it "records the first view" do
    get("/api/v1/worker/leads/#{request_record.public_id}", headers:)
    expect(json.dig("data", "status")).to eq("viewed")
    expect(request_record.invitations.reload.sole.viewed_at).to be_present
  end

  it "hides requests the worker wasn't invited to" do
    other = create(:service_request, :open)
    get("/api/v1/worker/leads/#{other.public_id}", headers:)
    expect(response).to have_http_status(:not_found)

    outsider = create(:worker_profile, :matchable, lat: 30.7333, lng: 76.7794, radius_m: 3000)
    get "/api/v1/worker/leads", headers: auth_headers_for(outsider.user, role: "worker")
    expect(json["data"]).to be_empty
  end

  it "drops declined, cancelled and expired leads" do
    post("/api/v1/worker/leads/#{request_record.public_id}/decline", params: { reason: "Too far" }.to_json, headers:)
    expect(response).to have_http_status(:no_content)
    expect(request_record.invitations.reload.sole.decline_reason).to eq("Too far")
    get("/api/v1/worker/leads", headers:)
    expect(json["data"]).to be_empty

    second = create(:service_request, :open)
    Matching::InviteWorkers.call(second)
    Requests::Cancel.call(request: second)
    get("/api/v1/worker/leads", headers:)
    expect(json["data"]).to be_empty
  end

  it "stays behind the verification gate" do
    worker.update!(available: false, suspended_at: Time.current, suspension_reason: "complaints")
    get("/api/v1/worker/leads", headers:)
    expect([ response.status, error_code ]).to eq([ 403, "worker_suspended" ])
    post("/api/v1/worker/leads/#{request_record.public_id}/decline", headers:)
    expect(response).to have_http_status(:forbidden)
  end
end
