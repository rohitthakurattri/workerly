require "rails_helper"

# Phase 7 exit gate: the ledger balances to zero across 1,000 simulated jobs, and duplicate
# webhooks have no effect.
RSpec.describe "Payments exit gate", type: :request do
  let!(:mohali) { create(:mohali) }
  let(:finance) { staff_auth(create(:user, :finance), role: "finance") }

  # A finished job written straight to the tables (the lifecycle itself is covered by the
  # Phase 6 gate), so 1,000 of them take seconds. Lines: labour + parts + travel.
  def finished_job(worker:, customer:, address:, category:, labour:, parts:, travel:)
    now = Time.current
    request = ServiceRequest.create!(customer:, service_category: category, address:, description: "Simulated job", status: "booked",
                                     city: mohali, location: address.location, address_snapshot: address.snapshot,
                                     submitted_at: now, expires_at: now + 1.day)
    invitation = RequestInvitation.create!(service_request: request, worker_profile: worker, rank: 1, rank_score: 0.5, distance_m: 500)
    quotation = Quotation.create!(service_request: request, worker_profile: worker, invitation:, kind: "fixed", status: "accepted",
                                  accepted_at: now, valid_until: now + 1.day)
    items = [ [ "labour", labour ], [ "material", parts ], [ "transport", travel ] ].reject { |_, a| a.zero? }
    subtotal = items.sum(&:last)
    tax = Quotations::Build.tax_for(subtotal, category.tax_rate_bps)
    revision = quotation.revisions.create!(version: 1, stage: "initial", subtotal_minor: subtotal, tax_rate_bps: category.tax_rate_bps,
                                           tax_minor: tax, total_minor: subtotal + tax, currency_code: "INR", created_by: worker.user)
    items.each_with_index do |(type, amount), i|
      revision.items.create!(position: i + 1, item_type: type, description: type, quantity: 1, unit: "job", unit_price_minor: amount, amount_minor: amount)
    end
    rule = CommissionRule.for(city: mohali, category:)
    booking = Booking.create!(service_request: request, quotation:, customer:, worker_profile: worker, kind: "fixed", status: "completed",
                              approved_total_minor: subtotal + tax, currency_code: "INR", confirmed_at: now, completed_at: now,
                              address_revealed_at: now, commission_bps: rule.percent_bps, commission_fixed_minor: rule.fixed_minor)
    BookingApproval.create!(booking:, quotation_revision: revision, decision: "approved", decided_by: customer)
    [ booking, labour, rule ]
  end

  it "balances to zero across 1,000 jobs: online, cash, duplicate webhooks, refunds and payouts" do
    rng = Random.new(1_000)
    CommissionRule.create!(percent_bps: 1000, fixed_minor: 0, effective_from: 1.year.ago)
    painter = create(:service_category, slug: "painter", tax_rate_bps: 1800)
    CommissionRule.create!(service_category: painter, percent_bps: 1250, fixed_minor: 2_500, effective_from: 1.year.ago)
    categories = [ create(:plumber), painter ]
    workers = Array.new(12) { create(:worker_profile, :matchable) }
    customers = Array.new(20) { create(:user) }
    addresses = customers.to_h { |c| [ c, create(:address, user: c) ] }

    expected = Hash.new(0)                       # independent model of every balance
    per_worker = Hash.new { |h, k| h[k] = Hash.new(0) }
    deliveries = 0

    1000.times do |n|
      worker = workers.sample(random: rng)
      customer = customers.sample(random: rng)
      category = categories.sample(random: rng)
      booking, labour, rule = finished_job(worker:, customer:, address: addresses[customer], category:,
                                           labour: rng.rand(1..300_000), parts: rng.rand < 0.5 ? rng.rand(1..200_000) : 0,
                                           travel: rng.rand < 0.2 ? rng.rand(1..20_000) : 0)
      total = booking.approved_total_minor
      tax = booking.approvals.sole.quotation_revision.tax_minor
      commission = [ ((labour * rule.percent_bps) + 5_000) / 10_000 + rule.fixed_minor, total - tax ].min

      if rng.rand < 0.6
        payment = Payments::CreateOrder.call(booking:, idempotency_key: "job-#{n}")
        body = webhook_body(payment)
        event_id = "evt_job_#{n}"
        (1 + rng.rand(3)).times do # Razorpay may deliver the same event more than once…
          deliver_webhook(body, event_id:)
          deliveries += 1
        end
        deliver_webhook(body, event_id: "evt_job_#{n}_again") if rng.rand < 0.2 # …or resend it under a new id
        expected[:clearing] += total
        expected[:revenue] += commission
        expected[:tax] += tax
        per_worker[worker.id][:payable] += total - commission - tax

        if rng.rand < 0.15
          payment.reload
          amount = rng.rand < 0.5 ? payment.amount_minor : rng.rand(1..payment.amount_minor)
          Refunds::Create.call(payment:, amount_minor: amount, reason: "Simulated", auth: finance)
          c = (amount * payment.commission_minor) / payment.amount_minor
          t = (amount * payment.tax_minor) / payment.amount_minor
          expected[:clearing] -= amount
          expected[:revenue] -= c
          expected[:tax] -= t
          per_worker[worker.id][:payable] -= amount - c - t
        end
      else
        Payments::RecordCash.call(booking:, worker: worker.user, amount_minor: total, idempotency_key: "cash-#{n}")
        expected[:revenue] += commission
        expected[:tax] += tax
        per_worker[worker.id][:owed] += commission + tax
      end
      expect(booking.reload.outstanding_minor).to eq(0)

      next unless (n % 100) == 99

      # Every 100 jobs finance pays out workers what they're owed.
      workers.each do |w|
        balance = Payouts::Balance.call(w)
        next unless balance.net_minor.positive?

        amount = rng.rand(1..balance.net_minor)
        Payouts::Create.call(worker: w, amount_minor: amount, reference: "UTR-#{n}-#{w.id}", auth: finance)
        offset = [ balance.owed_minor, balance.payable_minor ].min
        per_worker[w.id][:payable] -= offset + amount
        per_worker[w.id][:owed] -= offset
        expected[:clearing] -= amount
      end
    end

    # 1. The ledger as a whole balances to zero, and so does every transaction.
    signed = Arel.sql("CASE direction WHEN 'debit' THEN amount_minor ELSE -amount_minor END")
    expect(Ledger::Entry.sum(signed)).to eq(0)
    expect(Ledger::Entry.group(:ledger_transaction_id).sum(signed).values.uniq).to eq([ 0 ])

    # 2. Every account matches the independent model.
    bal = ->(kind, owner = nil) { Ledger::Account.find_by(kind:, owner:)&.balance_minor.to_i }
    expect(bal.("gateway_clearing")).to eq(expected[:clearing])
    expect(-bal.("platform_revenue")).to eq(expected[:revenue])
    expect(-bal.("tax_payable")).to eq(expected[:tax])
    workers.each do |w|
      expect(Payouts::Balance.call(w)).to have_attributes(payable_minor: per_worker[w.id][:payable], owed_minor: per_worker[w.id][:owed])
    end

    # 3. Duplicate deliveries changed nothing: one capture posting per online payment.
    online = Payment.where(method: "online")
    expect(Ledger::Transaction.where(kind: "payment_captured").count).to eq(online.count)
    expect(PaymentEvent.count).to be < deliveries
    expect(Booking.where(status: %w[paid refunded]).count).to eq(1000)
    expect(Invoice.count).to eq(1000)
    expect(Invoice.pluck(:number).map { |x| x.split("/").last.to_i }.sort).to eq((1..1000).to_a)

    report = Finance::Reconciliation.call(from: 1.day.ago, to: 1.minute.from_now)
    expect(report).to include(ledger_balanced: true)
    expect(report[:issues]).to include(payments_without_ledger: [], amount_mismatches: [])
  end

  describe "duplicate webhooks over HTTP" do
    let(:booking) { completed_booking! }

    it "answers 200 to every redelivery but applies the event once; refuses bad signatures" do
      payment = Payments::CreateOrder.call(booking:, idempotency_key: "x")
      body = webhook_body(payment)
      headers = { "Content-Type" => "application/json", "X-Razorpay-Signature" => sign_webhook(body), "X-Razorpay-Event-Id" => "evt_1" }

      3.times do
        post("/api/v1/webhooks/razorpay", params: body, headers:)
        expect(response).to have_http_status(:ok)
      end
      expect(json["status"]).to eq("duplicate")
      expect(PaymentEvent.count).to eq(1)
      expect(Ledger::Transaction.count).to eq(1)
      expect(booking.reload.paid_minor).to eq(95_000)

      post("/api/v1/webhooks/razorpay", params: body, headers: headers.merge("X-Razorpay-Signature" => "nope", "X-Razorpay-Event-Id" => "evt_2"))
      expect(response).to have_http_status(:unauthorized)
      post("/api/v1/webhooks/razorpay", params: body.sub("95000", "1"), headers: headers.merge("X-Razorpay-Event-Id" => "evt_3"))
      expect(response).to have_http_status(:unauthorized) # tampered body, old signature
    end
  end

  describe "the same webhook delivered concurrently" do
    self.use_transactional_tests = false

    after do
      truncate_committed_data!
    end

    it "posts once when deliveries race, with the same or different event ids" do
      CommissionRule.create!(percent_bps: 1000, fixed_minor: 0, effective_from: 1.year.ago)
      payment = Payments::CreateOrder.call(booking: completed_booking!, idempotency_key: "race")
      body = webhook_body(payment)
      gate = Concurrent::CountDownLatch.new(1)
      threads = %w[evt_a evt_a evt_b evt_c].map do |id|
        Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            gate.wait
            deliver_webhook(body, event_id: id).status
          end
        end
      end
      gate.count_down
      statuses = threads.map(&:value)

      expect(statuses.count(:duplicate)).to be >= 1
      expect(Ledger::Transaction.where(kind: "payment_captured").count).to eq(1)
      expect(payment.reload).to be_captured
      expect(payment.booking.reload).to have_attributes(paid_minor: payment.amount_minor, status: "paid")
      expect(Invoice.count).to eq(1)
    end
  end
end
