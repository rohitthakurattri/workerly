require "rails_helper"

RSpec.describe "Payments API", type: :request do
  let!(:mohali) { create(:mohali) }
  let!(:rule) { CommissionRule.create!(percent_bps: 1000, fixed_minor: 0, effective_from: 1.year.ago) }
  let(:booking) { completed_booking! }
  let(:customer) { auth_headers_for(booking.customer) }
  let(:worker) { auth_headers_for(booking.worker_profile.user, role: "worker") }
  let(:finance) { staff_headers_for(create(:user, :finance), role: "finance") }
  let(:key) { { "Idempotency-Key" => SecureRandom.uuid } }

  it "pays online end to end: order, checkout callback, webhook, receipt" do
    post("/api/v1/customer/bookings/#{booking.public_id}/payments", headers: customer.merge(key))
    expect(response).to have_http_status(:created)
    checkout = json.dig("data", "checkout")
    expect(checkout).to include("provider" => "fake", "amount" => 95_000, "currency" => "INR")
    payment_id = json.dig("data", "payment", "id")

    post("/api/v1/dev/fake_payments/#{checkout['order_id']}/capture")
    callback = json["data"]
    post("/api/v1/customer/payments/#{payment_id}/verify", params: callback.to_json, headers: customer)
    expect(json.dig("data", "status")).to eq("captured")
    post("/api/v1/customer/payments/#{payment_id}/verify", params: callback.merge("razorpay_signature" => "x").to_json, headers: customer)
    expect(error_code).to eq("invalid_signature")

    get("/api/v1/customer/bookings/#{booking.public_id}", headers: customer)
    expect(json["data"]).to include("status" => "paid", "payable" => false, "invoice_number" => start_with("WK/"))
    expect(json.dig("data", "outstanding", "minor")).to eq(0)
    get("/api/v1/customer/bookings/#{booking.public_id}/invoice", headers: customer)
    expect(json["data"]).to include("total" => { "minor" => 95_000, "currency" => "INR" })
    expect(json.dig("data", "parties", "worker", "name")).to eq(booking.worker_profile.user.name)

    get("/api/v1/customer/payments/#{payment_id}", headers: auth_headers_for(create(:user)))
    expect(response).to have_http_status(:not_found)
  end

  it "refuses to start a payment when nothing is owed or the job isn't done" do
    post("/api/v1/customer/bookings/#{booked!.public_id}/payments", headers: customer.merge(key))
    expect(response).to have_http_status(:not_found) # someone else's booking
    open = booked!(customer: booking.customer)
    post("/api/v1/customer/bookings/#{open.public_id}/payments", headers: customer.merge(key))
    expect(error_code).to eq("nothing_to_pay")
    post("/api/v1/customer/bookings/#{booking.public_id}/payments", headers: customer)
    expect(error_code).to eq("idempotency_key_required")
  end

  it "lets the worker record cash, once, for the exact amount, and shows earnings" do
    post("/api/v1/worker/bookings/#{booking.public_id}/cash_received", params: { amount_minor: 1 }.to_json, headers: worker.merge(key))
    expect(error_code).to eq("amount_mismatch")
    cash_key = { "Idempotency-Key" => "cash-#{booking.public_id}" }
    2.times { post("/api/v1/worker/bookings/#{booking.public_id}/cash_received", params: { amount_minor: 95_000 }.to_json, headers: worker.merge(cash_key)) }
    expect(response.headers["Idempotent-Replayed"]).to eq("true")
    expect(booking.payments.count).to eq(1)

    get("/api/v1/worker/earnings", headers: worker)
    expect(json.dig("data", "balance")).to include("owed" => { "minor" => 9_500, "currency" => "INR" })
    expect(json.dig("data", "jobs").sole).to include("method" => "cash", "commission" => { "minor" => 9_500, "currency" => "INR" })
    get("/api/v1/worker/bookings/#{booking.public_id}/invoice", headers: worker)
    expect(response).to have_http_status(:ok)
  end

  describe "finance" do
    before { pay_online!(booking) }

    it "refunds (finance only, audited, idempotent) and shows it in the payments list" do
      payment = booking.payments.sole
      body = { amount_minor: 5_000, reason: "Late arrival" }.to_json
      post("/api/v1/admin/payments/#{payment.public_id}/refunds", params: body,
                                                                 headers: staff_headers_for(create(:user, :support), role: "support").merge(key))
      expect(response).to have_http_status(:forbidden)
      2.times { post("/api/v1/admin/payments/#{payment.public_id}/refunds", params: body, headers: finance.merge(key)) }
      expect(response).to have_http_status(:created)
      expect(payment.refunds.count).to eq(1)
      expect(json["data"]).to include("status" => "partially_refunded", "refundable" => { "minor" => 90_000, "currency" => "INR" })

      get("/api/v1/admin/payments?filter[method]=online", headers: finance)
      expect(json["data"].sole["refunds"].sole).to include("status" => "processed")
    end

    it "lists balances, records payouts and reconciles" do
      get("/api/v1/admin/finance/balances", headers: finance)
      row = json["data"].sole
      expect(row).to include("held" => { "minor" => 85_500, "currency" => "INR" })

      post("/api/v1/admin/finance/payouts", params: { worker_id: row["worker_id"], amount_minor: 85_501, reference: "UTR9" }.to_json, headers: finance.merge(key))
      expect(error_code).to eq("payout_too_large")
      post("/api/v1/admin/finance/payouts", params: { worker_id: row["worker_id"], amount_minor: 85_500, reference: "UTR9" }.to_json,
                                            headers: finance.merge("Idempotency-Key" => "payout-1"))
      expect(response).to have_http_status(:created)

      get("/api/v1/admin/finance/reconciliation", headers: finance)
      expect(json["data"]).to include("ledger_balanced" => true, "online_captured_minor" => 95_000, "payouts_minor" => 85_500)
      expect(json.dig("data", "balances", "gateway_clearing")).to eq(9_500)

      get("/api/v1/admin/finance/reconciliation", headers: staff_headers_for(create(:user, :support), role: "support"))
      expect(response).to have_http_status(:forbidden)
    end

    it "adds commission rules (never edits them) and audits it" do
      post("/api/v1/admin/finance/commission_rules", params: { category: "plumber", percent_bps: 1200, fixed_minor: 1_000 }.to_json, headers: finance)
      expect(response).to have_http_status(:created)
      get("/api/v1/admin/finance/commission_rules", headers: finance)
      expect(json["data"].map { |r| [ r["category"], r["percent_bps"] ] }).to include([ "plumber", 1200 ], [ nil, 1000 ])
      expect(AdminAction.last.action).to eq("commission_rule.created")
    end
  end
end
