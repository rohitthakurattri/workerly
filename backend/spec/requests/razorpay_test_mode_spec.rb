require "rails_helper"

# Razorpay in test mode on a machine no webhook can reach: the app asks Razorpay what happened
# (authenticated with our secret) right after checkout, while polling, and in a sweep job.
RSpec.describe "Razorpay test mode", type: :request do
  let!(:mohali) { create(:mohali) }
  let!(:rule) { CommissionRule.create!(percent_bps: 1000, fixed_minor: 0, effective_from: 1.year.ago) }
  let(:booking) { completed_booking! }
  let(:customer) { auth_headers_for(booking.customer) }
  let(:api) { "https://api.razorpay.com/v1" }
  let(:order_id) { "order_Test#{SecureRandom.hex(4)}" }

  before { with_config(payment_adapter: "razorpay", razorpay_key_id: "rzp_test_abc123") }

  def start_payment
    stub_request(:post, "#{api}/orders").with(basic_auth: [ "rzp_test_abc123", Workerly.config.razorpay_key_secret ])
                                        .to_return(status: 200, body: { id: order_id, amount: 95_000, currency: "INR" }.to_json)
    post("/api/v1/customer/bookings/#{booking.public_id}/payments", headers: customer.merge("Idempotency-Key" => SecureRandom.uuid))
    json.dig("data", "payment", "id")
  end

  def attempts(*list) = stub_request(:get, "#{api}/orders/#{order_id}/payments").to_return(status: 200, body: { items: list }.to_json)

  def callback(payment_id = "pay_Test1")
    { razorpay_order_id: order_id, razorpay_payment_id: payment_id,
      razorpay_signature: Adapters::Payments.hmac(Workerly.config.razorpay_key_secret, "#{order_id}|#{payment_id}") }
  end

  it "hands the checkout the test key and settles the payment from Razorpay's answer after checkout" do
    id = start_payment
    expect(json.dig("data", "checkout")).to include("provider" => "razorpay", "key_id" => "rzp_test_abc123", "order_id" => order_id)

    attempts({ id: "pay_Test1", status: "captured", amount: 95_000, currency: "INR" })
    post("/api/v1/customer/payments/#{id}/verify", params: callback.to_json, headers: customer)
    expect(json.dig("data", "status")).to eq("captured")
    expect(booking.reload).to have_attributes(status: "paid", outstanding_minor: 0)
    expect(Payment.find_by!(public_id: id)).to have_attributes(provider_payment_id: "pay_Test1", commission_minor: 9_500)
  end

  it "keeps polling through 'authorized' until Razorpay reports the capture" do
    id = start_payment
    attempts({ id: "pay_Test1", status: "authorized", amount: 95_000, currency: "INR" })
    post("/api/v1/customer/payments/#{id}/verify", params: callback.to_json, headers: customer)
    expect(json.dig("data", "status")).to eq("created")

    attempts({ id: "pay_Test1", status: "captured", amount: 95_000, currency: "INR" })
    get("/api/v1/customer/payments/#{id}", headers: customer)
    expect(json.dig("data", "status")).to eq("captured")
  end

  it "never trusts the browser: a forged callback changes nothing and Razorpay isn't asked" do
    id = start_payment
    pull = attempts({ id: "pay_Test1", status: "captured", amount: 95_000, currency: "INR" })
    post("/api/v1/customer/payments/#{id}/verify", params: callback.merge(razorpay_signature: "forged").to_json, headers: customer)
    expect(error_code).to eq("invalid_signature")
    expect(pull).not_to have_been_requested
  end

  it "flags a capture for a different amount instead of settling it" do
    id = start_payment
    attempts({ id: "pay_Test1", status: "captured", amount: 100, currency: "INR" })
    post("/api/v1/customer/payments/#{id}/verify", params: callback.to_json, headers: customer)
    expect(json.dig("data", "status")).to eq("amount_mismatch")
    expect(booking.reload.status).to eq("completed")
  end

  it "still answers when Razorpay can't be reached (the webhook or the sweep settles it later)" do
    id = start_payment
    stub_request(:get, "#{api}/orders/#{order_id}/payments").to_timeout
    post("/api/v1/customer/payments/#{id}/verify", params: callback.to_json, headers: customer)
    expect(response).to have_http_status(:ok)
    expect(json.dig("data", "status")).to eq("created")
  end

  describe Payments::SyncPendingJob do
    it "settles orders whose webhook never came, and fails abandoned ones only after 30 minutes" do
      id = start_payment
      payment = Payment.find_by!(public_id: id)
      attempts({ id: "pay_X", status: "failed", amount: 95_000, currency: "INR", error_description: "Card declined" })

      described_class.perform_now(now: 10.minutes.from_now)
      expect(payment.reload.status).to eq("created") # the customer may still be retrying
      described_class.perform_now(now: 31.minutes.from_now)
      expect(payment.reload).to have_attributes(status: "failed", failure_reason: "Card declined")
    end

    it "captures a paid order and completes a pending refund from Razorpay's answer" do
      id = start_payment
      payment = Payment.find_by!(public_id: id)
      attempts({ id: "pay_Y", status: "captured", amount: 95_000, currency: "INR" })
      described_class.perform_now(now: 3.minutes.from_now)
      expect(payment.reload.status).to eq("captured")

      stub_request(:post, "#{api}/payments/pay_Y/refund").to_return(status: 200, body: { id: "rfnd_1", status: "pending" }.to_json)
      refund = Refunds::Create.call(payment:, amount_minor: 10_000, reason: "test", auth: staff_auth(create(:user, :finance), role: "finance"))
      expect(refund.status).to eq("pending")
      stub_request(:get, "#{api}/refunds/rfnd_1").to_return(status: 200, body: { id: "rfnd_1", status: "processed" }.to_json)
      described_class.perform_now(now: 3.minutes.from_now)
      expect(refund.reload.status).to eq("processed")
      expect(payment.reload).to have_attributes(status: "partially_refunded", refunded_minor: 10_000)
    end

    it "carries on past an order Razorpay can't answer for" do
      start_payment
      stub_request(:get, "#{api}/orders/#{order_id}/payments").to_return(status: 500, body: "{}")
      expect { described_class.perform_now(now: 3.minutes.from_now) }.not_to raise_error
    end
  end

  describe "keys" do
    def config(**o) = Workerly::Config.new(**Workerly.config.to_h.merge(payment_adapter: "razorpay", **o))

    it "allows test keys everywhere but production, and live keys only in production" do
      expect { Workerly.check_razorpay_keys!(config(razorpay_key_id: "rzp_test_x"), false) }.not_to raise_error
      expect { Workerly.check_razorpay_keys!(config(razorpay_key_id: "rzp_live_x"), false) }.to raise_error(/live Razorpay keys outside production/)
      expect { Workerly.check_razorpay_keys!(config(razorpay_key_id: "rzp_test_x"), true) }.to raise_error(/needs live Razorpay keys/)
      expect { Workerly.check_razorpay_keys!(config(razorpay_key_id: "rzp_live_x"), true) }.not_to raise_error
      expect { Workerly.check_razorpay_keys!(config(razorpay_key_id: nil), false) }.to raise_error(/needs RAZORPAY_KEY_ID/)
    end
  end
end
