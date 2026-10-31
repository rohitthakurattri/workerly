require "rails_helper"

RSpec.describe "Customer quotations", type: :request do
  let!(:mohali) { create(:mohali) }
  let(:customer) { create(:user) }
  let!(:matched) { matched_request(workers: 3, customer:) }
  let(:service_request) { matched.first }
  let(:workers) { matched.last }
  let(:headers) { auth_headers_for(customer) }
  let!(:quotes) do
    [ quote!(workers[0], service_request, fixed_quote(90_000)), quote!(workers[1], service_request, fixed_quote(60_000)),
      quote!(workers[2], service_request, { kind: "inspection", inspection_fee_minor: 19_900, notes: "Need to see it" }) ]
  end

  def accept(q, version: 1, key: SecureRandom.uuid, as: headers)
    post "/api/v1/customer/quotations/#{q.public_id}/accept", params: { version: }.to_json, headers: as.merge("Idempotency-Key" => key)
  end

  it "lists quotes cheapest first with the worker card, never the worker's phone" do
    get("/api/v1/customer/service_requests/#{service_request.public_id}/quotations", headers:)
    expect(json["data"].map { |q| q.dig("revision", "total", "minor") }).to eq([ 19_900, 60_000, 90_000 ])
    first = json["data"].first
    expect(first).to include("kind" => "inspection", "status" => "submitted", "revised" => false, "distance_band" => "under_1km")
    expect(first["worker"]).to include("name" => workers[2].user.name, "verified" => true, "jobs_done" => 0)
    expect(first["worker"]).not_to have_key("phone")
    workers.each { |w| expect(response.body).not_to include(w.user.phone_e164) }

    get("/api/v1/customer/service_requests/#{service_request.public_id}", headers:)
    expect(json["data"]).to include("status" => "quoting", "quotes_count" => 3)
  end

  it "hides withdrawn quotes and other customers' quotes" do
    Quotations::Withdraw.call(quotation: quotes[0])
    get("/api/v1/customer/service_requests/#{service_request.public_id}/quotations", headers:)
    expect(json["data"].size).to eq(2)
    get("/api/v1/customer/quotations/#{quotes[0].public_id}", headers:)
    expect(response).to have_http_status(:not_found)

    stranger = auth_headers_for(create(:user))
    get("/api/v1/customer/quotations/#{quotes[1].public_id}", headers: stranger)
    expect(response).to have_http_status(:not_found)
    accept(quotes[1], as: stranger)
    expect(response).to have_http_status(:not_found)
    get("/api/v1/customer/service_requests/#{service_request.public_id}/quotations", headers: stranger)
    expect(response).to have_http_status(:not_found)
  end

  it "shows a quote's price history" do
    Quotations::Revise.call(quotation: quotes[0], params: fixed_quote(85_000).with_indifferent_access, actor: workers[0].user)
    get("/api/v1/customer/quotations/#{quotes[0].public_id}", headers:)
    expect(json["data"]).to include("current_version" => 2, "revised" => true)
    expect(json.dig("data", "revisions").map { |r| r.dig("total", "minor") }).to eq([ 90_000, 85_000 ])
  end

  it "accepts a quote: the booking reveals the worker's phone, and everyone else is told" do
    clear_enqueued_jobs
    expect { perform_enqueued_jobs { accept(quotes[1]) } }.to change { Adapters::Sms::Fake.deliveries.size }.by(1) # the winner (no push device)
    expect(response).to have_http_status(:created)
    booking = json["data"]
    expect(booking).to include("status" => "confirmed", "kind" => "fixed", "request_id" => service_request.public_id)
    expect(booking["approved_total"]).to eq("minor" => 60_000, "currency" => "INR")
    expect(booking.dig("worker", "phone")).to eq(workers[1].user.phone_e164)
    expect(Adapters::Sms::Fake.deliveries.last.to).to eq(workers[1].user.phone_e164)
    expect(workers[1].user.notifications.last.kind).to eq("quote.accepted")
    expect(workers[0].user.notifications.last.kind).to eq("quote.lost")

    get("/api/v1/customer/bookings/#{booking['id']}", headers:)
    expect(json.dig("data", "id")).to eq(booking["id"])
    get("/api/v1/customer/service_requests/#{service_request.public_id}", headers:)
    expect(json["data"]).to include("status" => "booked", "booking_id" => booking["id"], "cancellable" => false)
    get("/api/v1/customer/bookings/#{booking['id']}", headers: auth_headers_for(create(:user)))
    expect(response).to have_http_status(:not_found)
  end

  it "needs an Idempotency-Key and the version the customer saw" do
    post("/api/v1/customer/quotations/#{quotes[0].public_id}/accept", params: { version: 1 }.to_json, headers:)
    expect(response).to have_http_status(:bad_request)
    expect(error_code).to eq("idempotency_key_required")

    Quotations::Revise.call(quotation: quotes[0], params: fixed_quote(99_000).with_indifferent_access, actor: workers[0].user)
    accept(quotes[0], version: 1, key: "stale-key-123")
    expect(response).to have_http_status(:conflict)
    expect(error_code).to eq("quotation_changed")
    expect(json.dig("error", "details", "current_version")).to eq(2)

    accept(quotes[0], version: 2, key: "stale-key-123") # a failed attempt doesn't burn the key…
    expect(response).to have_http_status(:created)
    accept(quotes[0], version: 3, key: "stale-key-123") # …but a used key can't carry a different body
    expect(error_code).to eq("idempotency_key_reused")
  end

  it "conflicts when the request is already booked" do
    accept(quotes[0])
    accept(quotes[1])
    expect(response).to have_http_status(:conflict)
    expect(error_code).to eq("request_already_booked")
  end

  it "declines one quote and keeps the rest" do
    perform_enqueued_jobs(only: Quotations::QuotationDecidedJob) do
      post("/api/v1/customer/quotations/#{quotes[0].public_id}/decline", params: { reason: "Too expensive" }.to_json, headers:)
    end
    expect(json["data"]).to include("status" => "declined", "decline_reason" => "Too expensive")
    expect(workers[0].user.notifications.last.kind).to eq("quote.declined")
    expect(quotes[1].reload).to be_submitted
  end

  it "is customer-only" do
    get "/api/v1/customer/service_requests/#{service_request.public_id}/quotations", headers: auth_headers_for(workers[0].user, role: "worker")
    expect(response).to have_http_status(:forbidden)
  end
end
