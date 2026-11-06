require "swagger_helper"

# Documents the Phase 7 endpoints. Behaviour: spec/requests/payments_gate_spec.rb, spec/requests/api/v1/payments_spec.rb.
RSpec.describe "Payments API docs", type: :request do
  let!(:mohali) { create(:mohali) }
  let!(:rule) { CommissionRule.create!(percent_bps: 1000, fixed_minor: 0, effective_from: 1.year.ago) }
  let(:booking) { completed_booking! }

  def self.money_header = parameter(name: "Idempotency-Key", in: :header, required: true, schema: { type: :string })

  context "as the customer" do
    let(:Authorization) { auth_headers_for(booking.customer)["Authorization"] }

    path "/api/v1/customer/bookings/{booking_id}/payments" do
      parameter name: :booking_id, in: :path, schema: { type: :string }
      post "Start paying online what's owed (gateway order + checkout details)" do
        tags "Payments"
        security [ bearer: [] ]
        parameter name: :Authorization, in: :header, schema: { type: :string }
        money_header
        let(:booking_id) { booking.public_id }
        let(:"Idempotency-Key") { SecureRandom.uuid }
        response "201", "order created" do
          schema type: :object, properties: { data: { "$ref" => "#/components/schemas/payment_order" } }
          run_test!
        end
        response "409", "nothing owed" do
          before { pay_online!(booking) }
          schema "$ref" => "#/components/schemas/error"
          run_test! { expect(error_code).to eq("nothing_to_pay") }
        end
      end
    end

    path "/api/v1/customer/payments/{id}" do
      parameter name: :id, in: :path, schema: { type: :string }
      get "Payment status (poll after checkout)" do
        tags "Payments"
        security [ bearer: [] ]
        parameter name: :Authorization, in: :header, schema: { type: :string }
        let(:id) { Payments::CreateOrder.call(booking:, idempotency_key: "d").public_id }
        response "200", "ok" do
          schema type: :object, properties: { data: { "$ref" => "#/components/schemas/payment" } }
          run_test!
        end
      end
    end

    path "/api/v1/customer/payments/{id}/verify" do
      parameter name: :id, in: :path, schema: { type: :string }
      post "Checkout callback: checks the signature; never marks paid (the webhook does)" do
        tags "Payments"
        security [ bearer: [] ]
        consumes "application/json"
        parameter name: :Authorization, in: :header, schema: { type: :string }
        parameter name: :body, in: :body, schema: { type: :object, required: %w[razorpay_payment_id razorpay_order_id razorpay_signature],
                                                    properties: { razorpay_payment_id: { type: :string }, razorpay_order_id: { type: :string }, razorpay_signature: { type: :string } } }
        let(:payment) { Payments::CreateOrder.call(booking:, idempotency_key: "v") }
        let(:id) { payment.public_id }
        let(:body) do
          { razorpay_payment_id: "pay_1", razorpay_order_id: payment.provider_order_id,
            razorpay_signature: Adapters::Payments.hmac(Workerly.config.razorpay_key_secret, "#{payment.provider_order_id}|pay_1") }
        end
        response "200", "signature valid" do
          schema type: :object, properties: { data: { "$ref" => "#/components/schemas/payment" } }
          run_test!
        end
        response "400", "bad signature" do
          let(:body) { { razorpay_payment_id: "pay_1", razorpay_order_id: payment.provider_order_id, razorpay_signature: "x" } }
          schema "$ref" => "#/components/schemas/error"
          run_test!
        end
      end
    end

    path "/api/v1/customer/bookings/{id}/invoice" do
      parameter name: :id, in: :path, schema: { type: :string }
      get "Invoice (once fully paid)" do
        tags "Payments"
        security [ bearer: [] ]
        parameter name: :Authorization, in: :header, schema: { type: :string }
        let(:id) { booking.public_id }
        response "200", "ok" do
          before { pay_online!(booking) }
          schema type: :object, properties: { data: { "$ref" => "#/components/schemas/invoice" } }
          run_test!
        end
        response "404", "not paid yet" do
          run_test!
        end
      end
    end
  end

  path "/api/v1/webhooks/razorpay" do
    post "Razorpay webhook (HMAC-SHA256 of the raw body in X-Razorpay-Signature; deduplicated by X-Razorpay-Event-Id)" do
      tags "Payments"
      consumes "application/json"
      parameter name: "X-Razorpay-Signature", in: :header, schema: { type: :string }
      parameter name: "X-Razorpay-Event-Id", in: :header, schema: { type: :string }
      parameter name: :body, in: :body, schema: { type: :object }
      let(:payment) { Payments::CreateOrder.call(booking:, idempotency_key: "w") }
      let(:body) { JSON.parse(webhook_body(payment)) }
      let(:"X-Razorpay-Signature") { sign_webhook(body.to_json) }
      let(:"X-Razorpay-Event-Id") { "evt_doc" }
      response "200", "processed or duplicate" do
        run_test! { expect(payment.reload).to be_captured }
      end
      response "401", "bad signature" do
        let(:"X-Razorpay-Signature") { "nope" }
        run_test!
      end
    end
  end

  context "as the worker" do
    let(:Authorization) { auth_headers_for(booking.worker_profile.user, role: "worker")["Authorization"] }

    path "/api/v1/worker/bookings/{id}/cash_received" do
      parameter name: :id, in: :path, schema: { type: :string }
      post "Customer paid in cash: confirm the exact amount owed" do
        tags "Payments"
        security [ bearer: [] ]
        consumes "application/json"
        parameter name: :Authorization, in: :header, schema: { type: :string }
        money_header
        parameter name: :body, in: :body, schema: { type: :object, required: %w[amount_minor], properties: { amount_minor: { type: :integer } } }
        let(:id) { booking.public_id }
        let(:"Idempotency-Key") { SecureRandom.uuid }
        let(:body) { { amount_minor: 95_000 } }
        response "200", "recorded" do
          schema type: :object, properties: { data: { "$ref" => "#/components/schemas/worker_booking" } }
          run_test!
        end
        response "422", "not the amount owed" do
          let(:body) { { amount_minor: 1 } }
          schema "$ref" => "#/components/schemas/error"
          run_test!
        end
      end
    end

    path "/api/v1/worker/earnings" do
      get "Balance, paid jobs with commission, payouts" do
        tags "Payments"
        security [ bearer: [] ]
        parameter name: :Authorization, in: :header, schema: { type: :string }
        response "200", "ok" do
          before { pay_online!(booking) }
          schema type: :object, properties: { data: { "$ref" => "#/components/schemas/earnings" } }
          run_test!
        end
      end
    end
  end

  context "as finance" do
    let(:Authorization) { staff_headers_for(create(:user, :finance), role: "finance")["Authorization"] }
    before { pay_online!(booking) }

    path "/api/v1/admin/payments" do
      get "Payments" do
        tags "Admin finance"
        security [ bearer: [] ]
        parameter name: :Authorization, in: :header, schema: { type: :string }
        parameter name: "filter[status]", in: :query, required: false, schema: { type: :string }
        parameter name: "filter[method]", in: :query, required: false, schema: { type: :string, enum: %w[online cash] }
        response "200", "ok" do
          schema type: :object, properties: { data: { type: :array, items: { "$ref" => "#/components/schemas/admin_payment" } } }
          run_test!
        end
      end
    end

    path "/api/v1/admin/payments/{id}/refunds" do
      parameter name: :id, in: :path, schema: { type: :string }
      post "Refund all or part of an online payment (finance, admin; audited)" do
        tags "Admin finance"
        security [ bearer: [] ]
        consumes "application/json"
        parameter name: :Authorization, in: :header, schema: { type: :string }
        money_header
        parameter name: :body, in: :body, schema: { type: :object, required: %w[amount_minor reason], properties: { amount_minor: { type: :integer }, reason: { type: :string } } }
        let(:id) { booking.payments.sole.public_id }
        let(:"Idempotency-Key") { SecureRandom.uuid }
        let(:body) { { amount_minor: 5_000, reason: "Late" } }
        response "201", "refunded" do
          schema type: :object, properties: { data: { "$ref" => "#/components/schemas/admin_payment" } }
          run_test!
        end
        response "422", "more than refundable" do
          let(:body) { { amount_minor: 10_000_000, reason: "x" } }
          schema "$ref" => "#/components/schemas/error"
          run_test!
        end
      end
    end

    path "/api/v1/admin/finance/balances" do
      get "Worker balances (held, owed commission, net)" do
        tags "Admin finance"
        security [ bearer: [] ]
        parameter name: :Authorization, in: :header, schema: { type: :string }
        response "200", "ok" do
          schema type: :object, properties: { data: { type: :array, items: { "$ref" => "#/components/schemas/worker_balance" } } }
          run_test!
        end
      end
    end

    path "/api/v1/admin/finance/payouts" do
      post "Record a bank/UPI payout (nets owed commission first; audited)" do
        tags "Admin finance"
        security [ bearer: [] ]
        consumes "application/json"
        parameter name: :Authorization, in: :header, schema: { type: :string }
        money_header
        parameter name: :body, in: :body, schema: { type: :object, required: %w[worker_id amount_minor reference],
                                                    properties: { worker_id: { type: :string }, amount_minor: { type: :integer }, reference: { type: :string } } }
        let(:"Idempotency-Key") { SecureRandom.uuid }
        let(:body) { { worker_id: booking.worker_profile.public_id, amount_minor: 10_000, reference: "UTR1" } }
        response "201", "recorded" do
          run_test!
        end
      end
    end

    path "/api/v1/admin/finance/reconciliation" do
      get "Reconciliation report" do
        tags "Admin finance"
        security [ bearer: [] ]
        parameter name: :Authorization, in: :header, schema: { type: :string }
        parameter name: :from, in: :query, required: false, schema: { type: :string }
        parameter name: :to, in: :query, required: false, schema: { type: :string }
        response "200", "ok" do
          schema type: :object, properties: { data: { "$ref" => "#/components/schemas/reconciliation" } }
          run_test! { expect(json.dig("data", "ledger_balanced")).to be(true) }
        end
      end
    end

    path "/api/v1/admin/finance/commission_rules" do
      get "Commission rules (newest first)" do
        tags "Admin finance"
        security [ bearer: [] ]
        parameter name: :Authorization, in: :header, schema: { type: :string }
        response "200", "ok" do
          schema type: :object, properties: { data: { type: :array, items: { "$ref" => "#/components/schemas/commission_rule" } } }
          run_test!
        end
      end
      post "Add a rule (rules are never edited; a later effective_from wins)" do
        tags "Admin finance"
        security [ bearer: [] ]
        consumes "application/json"
        parameter name: :Authorization, in: :header, schema: { type: :string }
        parameter name: :body, in: :body, schema: { type: :object, required: %w[percent_bps],
                                                    properties: { city: { type: :string }, category: { type: :string }, percent_bps: { type: :integer },
                                                                  fixed_minor: { type: :integer }, effective_from: { type: :string } } }
        let(:body) { { category: "plumber", percent_bps: 1200 } }
        response "201", "created" do
          schema type: :object, properties: { data: { "$ref" => "#/components/schemas/commission_rule" } }
          run_test!
        end
      end
    end
  end
end
