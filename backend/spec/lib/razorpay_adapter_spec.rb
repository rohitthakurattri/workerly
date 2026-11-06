require "rails_helper"

RSpec.describe Adapters::Payments::Razorpay do
  subject(:adapter) { described_class.new }

  before { with_config(razorpay_key_id: "rzp_test_key", razorpay_key_secret: "secret", razorpay_webhook_secret: "whsec") }

  it "creates orders with basic auth and amounts in paise" do
    stub = stub_request(:post, "https://api.razorpay.com/v1/orders").with(basic_auth: %w[rzp_test_key secret],
                                                                          body: hash_including("amount" => 95_000, "currency" => "INR", "receipt" => "r1"))
                                                                    .to_return(status: 200, body: { id: "order_123", amount: 95_000 }.to_json)
    expect(adapter.create_order(amount_minor: 95_000, currency: "INR", receipt: "r1")).to include(id: "order_123")
    expect(stub).to have_been_requested
  end

  it "raises a typed error on gateway errors and timeouts" do
    stub_request(:post, %r{razorpay.com/v1/payments/pay_1/refund}).to_return(status: 400, body: { error: { description: "Too much" } }.to_json)
    expect { adapter.refund(provider_payment_id: "pay_1", amount_minor: 1) }.to raise_error(Adapters::Payments::Error, "Too much")
    stub_request(:post, %r{razorpay.com/v1/orders}).to_timeout
    expect { adapter.create_order(amount_minor: 1, currency: "INR", receipt: "x") }.to raise_error(Adapters::Payments::Error) { |e| expect(e.code).to eq(:gateway_unavailable) }
  end

  it "checks Razorpay's signatures" do
    sig = OpenSSL::HMAC.hexdigest("SHA256", "secret", "order_1|pay_1")
    expect(adapter.checkout_signature_valid?(order_id: "order_1", payment_id: "pay_1", signature: sig)).to be(true)
    expect(adapter.checkout_signature_valid?(order_id: "order_1", payment_id: "pay_2", signature: sig)).to be(false)
    body = '{"event":"payment.captured"}'
    expect(adapter.webhook_signature_valid?(body:, signature: OpenSSL::HMAC.hexdigest("SHA256", "whsec", body))).to be(true)
    expect(adapter.webhook_signature_valid?(body:, signature: "")).to be(false)
  end

  it "refuses to run without keys" do
    with_config(razorpay_key_id: nil)
    expect { adapter.create_order(amount_minor: 1, currency: "INR", receipt: "x") }.to raise_error(Adapters::Payments::Error) { |e| expect(e.code).to eq(:not_configured) }
  end
end
