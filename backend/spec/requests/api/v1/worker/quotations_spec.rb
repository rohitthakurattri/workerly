require "rails_helper"

RSpec.describe "Worker quotations", type: :request do
  let!(:mohali) { create(:mohali) }
  let(:customer) { create(:user) }
  let!(:matched) { matched_request(workers: 2, customer:) }
  let(:service_request) { matched.first }
  let(:worker) { matched.last.first }
  let(:other_worker) { matched.last.last }
  let(:headers) { auth_headers_for(worker.user, role: "worker") }

  def submit_quote(body = QuoteHelpers::FIXED, as: headers, lead: service_request.public_id)
    post "/api/v1/worker/leads/#{lead}/quotations", params: body.to_json, headers: as
  end

  it "sends a quote and shows it on the lead" do
    submit_quote
    expect(response).to have_http_status(:created)
    expect(json["data"]).to include("lead_id" => service_request.public_id, "kind" => "fixed", "status" => "submitted",
                                    "current_version" => 1, "editable" => true)
    expect(json.dig("data", "revision", "total")).to eq("minor" => 95_000, "currency" => "INR")
    expect(json.dig("data", "revision", "items").map { |i| i["type"] }).to eq(%w[labour material])

    get("/api/v1/worker/leads/#{service_request.public_id}", headers:)
    expect(json["data"]).to include("status" => "quoted", "quotes_count" => 1, "quotes_full" => false)
    expect(json.dig("data", "quotation", "id")).to be_present
    expect(json.dig("data", "category", "inspection_allowed")).to be(true)
  end

  it "returns field errors for a bad quote" do
    submit_quote({ kind: "fixed", items: [ { type: "labour", description: "", quantity: 1, unit: "job", unit_price_minor: 100 } ] })
    expect(response).to have_http_status(:unprocessable_content)
    expect(error_code).to eq("validation_failed")
    expect(json.dig("error", "details", "field_errors")).to have_key("items.0.description")
  end

  it "404s on requests the worker wasn't invited to or declined" do
    stranger = create(:worker_profile, :matchable, lat: 30.7333, lng: 76.7794, radius_m: 3000)
    submit_quote(as: auth_headers_for(stranger.user, role: "worker"))
    expect(response).to have_http_status(:not_found)

    post("/api/v1/worker/leads/#{service_request.public_id}/decline", headers:)
    submit_quote
    expect(response).to have_http_status(:not_found)
  end

  it "403s for unapproved or suspended workers" do
    worker.update!(suspended_at: Time.current, available: false)
    submit_quote
    expect(response).to have_http_status(:forbidden)
    expect(error_code).to eq("worker_suspended")
  end

  it "conflicts on a second quote and when the request is full" do
    with_config(max_quotes_per_request: 1)
    submit_quote
    submit_quote
    expect(response).to have_http_status(:conflict)
    expect(error_code).to eq("already_quoted")

    get("/api/v1/worker/leads/#{service_request.public_id}", headers: auth_headers_for(other_worker.user, role: "worker"))
    expect(json["data"]).to include("quotes_full" => true)
    submit_quote(as: auth_headers_for(other_worker.user, role: "worker"))
    expect(error_code).to eq("quote_limit_reached")
  end

  it "revises (a new version) and withdraws a quote" do
    submit_quote
    id = json.dig("data", "id")
    patch("/api/v1/worker/quotations/#{id}", params: fixed_quote(80_000).to_json, headers:)
    expect(response).to have_http_status(:ok)
    expect(json["data"]).to include("current_version" => 2)
    expect(json.dig("data", "revision", "total", "minor")).to eq(80_000)

    post("/api/v1/worker/quotations/#{id}/withdraw", headers:)
    expect(json.dig("data", "status")).to eq("withdrawn")
    patch("/api/v1/worker/quotations/#{id}", params: fixed_quote(1).to_json, headers:)
    expect(error_code).to eq("quotation_not_editable")
  end

  it "lists only the worker's own quotes and hides other workers' quotes" do
    submit_quote
    submit_quote(fixed_quote(10_000), as: auth_headers_for(other_worker.user, role: "worker"))
    get("/api/v1/worker/quotations", headers:)
    expect(json["data"].size).to eq(1)
    expect(response.body).not_to include("10000")

    other_id = other_worker.quotations.sole.public_id
    get("/api/v1/worker/quotations/#{other_id}", headers:)
    expect(response).to have_http_status(:not_found)
    patch("/api/v1/worker/quotations/#{other_id}", params: fixed_quote(1).to_json, headers:)
    expect(response).to have_http_status(:not_found)

    get("/api/v1/worker/quotations?filter[status]=bogus", headers:)
    expect(response).to have_http_status(:bad_request)
  end

  it "shows the job, with the customer's contact and address, only to the worker who won it" do
    service_request.update!(description: "Tap leaking, call 98765 43210")
    q = quote!(worker, service_request)
    quote!(other_worker, service_request)
    booking = Quotations::Accept.call(quotation: q, version: 1, customer:)

    get("/api/v1/worker/bookings/#{booking.public_id}", headers:)
    expect(json["data"]).to include("status" => "confirmed", "customer" => { "name" => customer.name, "phone" => customer.phone_e164 },
                                    "description" => "Tap leaking, call 98765 43210")
    expect(json.dig("data", "address", "line1")).to eq("House 1234, Sector 70")
    expect(json.dig("data", "approved_total", "minor")).to eq(95_000)

    loser = auth_headers_for(other_worker.user, role: "worker")
    get("/api/v1/worker/bookings/#{booking.public_id}", headers: loser)
    expect(response).to have_http_status(:not_found)
    get("/api/v1/worker/quotations/#{other_worker.quotations.sole.public_id}", headers: loser)
    expect(json.dig("data", "status")).to eq("declined")
    expect(json.dig("data", "decline_reason")).to be_nil
    get("/api/v1/worker/leads", headers: loser)
    expect(json["data"]).to be_empty

    worker.update!(suspended_at: Time.current, available: false)
    get("/api/v1/worker/bookings/#{booking.public_id}", headers:)
    expect(response).to have_http_status(:forbidden)
  end
end
