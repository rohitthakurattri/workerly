require "rails_helper"

RSpec.describe "Money flow", type: :service do
  let!(:mohali) { create(:mohali) }
  let!(:rule) { CommissionRule.create!(percent_bps: 1000, fixed_minor: 0, effective_from: 1.year.ago) }
  let(:finance) { staff_auth(create(:user, :finance), role: "finance") }

  def balance(kind, owner: nil) = Ledger::Account.find_by(kind:, owner:)&.balance_minor.to_i
  def code_of
    yield
    nil
  rescue ApplicationError => e
    e.code
  end

  it "takes 10% of labour only (never parts), posts a balanced ledger and marks the job paid with an invoice" do
    b = completed_booking!(amount_minor: 95_000) # one labour line
    payment = pay_online!(b)

    expect(payment).to have_attributes(status: "captured", commission_minor: 9_500, tax_minor: 0, worker_share_minor: 85_500)
    expect(b.reload).to have_attributes(status: "paid", paid_minor: 95_000, outstanding_minor: 0)
    expect(balance("gateway_clearing")).to eq(95_000)
    expect(balance("platform_revenue")).to eq(-9_500)
    expect(balance("worker_payable", owner: b.worker_profile)).to eq(-85_500)
    expect(Ledger::Entry.sum(Arel.sql("CASE direction WHEN 'debit' THEN amount_minor ELSE -amount_minor END"))).to eq(0)
    expect(b.invoice).to have_attributes(total_minor: 95_000, number: match(%r{\AWK/20\d\d-\d\d/000001\z}))
    expect(b.status_histories.last).to have_attributes(to_status: "paid", actor_role: "system")
  end

  it "applies the most specific commission rule, snapshotted at booking" do
    CommissionRule.create!(service_category: create(:plumber), percent_bps: 1500, fixed_minor: 2_000, effective_from: 1.day.ago)
    b = completed_booking!(amount_minor: 100_000)
    expect(b).to have_attributes(commission_bps: 1500, commission_fixed_minor: 2_000)
    CommissionRule.create!(service_category: create(:plumber), percent_bps: 4000, effective_from: 1.minute.ago) # later change doesn't apply
    expect(pay_online!(b).commission_minor).to eq(17_000)
  end

  it "keeps parts out of the commission and tax with the tax account" do
    create(:plumber).update!(tax_rate_bps: 1800)
    b = completed_booking!(amount_minor: 10_000)
    payment = pay_online!(b)
    expect(payment).to have_attributes(amount_minor: 11_800, tax_minor: 1_800, commission_minor: 1_000, worker_share_minor: 9_000)
    expect(balance("tax_payable")).to eq(-1_800)
  end

  it "records cash: the worker keeps the money and owes the commission" do
    b = completed_booking!(amount_minor: 50_000)
    expect(code_of { Payments::RecordCash.call(booking: b, worker: b.worker_profile.user, amount_minor: 1, idempotency_key: "k1") }).to eq("amount_mismatch")
    Payments::RecordCash.call(booking: b, worker: b.worker_profile.user, amount_minor: 50_000, idempotency_key: "k1")
    expect(b.reload).to have_attributes(status: "paid")
    expect(Payouts::Balance.call(b.worker_profile)).to have_attributes(payable_minor: 0, owed_minor: 5_000, net_minor: -5_000)
    expect(balance("gateway_clearing")).to eq(0)
  end

  it "ignores a capture for the wrong amount and flags it" do
    b = completed_booking!
    payment = Payments::CreateOrder.call(booking: b, idempotency_key: "x")
    deliver_webhook(webhook_body(payment, amount: 1))
    expect(payment.reload).to have_attributes(status: "amount_mismatch")
    expect(Ledger::Transaction.count).to eq(0)
    expect(b.reload).to have_attributes(status: "completed", paid_minor: 0)
  end

  it "refuses unsigned webhooks and records failed payments" do
    b = completed_booking!
    payment = Payments::CreateOrder.call(booking: b, idempotency_key: "x")
    body = webhook_body(payment)
    expect(Payments::HandleWebhook.call(body:, signature: "forged", event_id: "e1").status).to eq(:invalid_signature)
    expect(PaymentEvent.count).to eq(0)
    deliver_webhook(webhook_body(payment, event: "payment.failed"))
    expect(payment.reload).to be_failed
  end

  it "reuses an unpaid order and only charges what's owed" do
    b = completed_booking!
    first = Payments::CreateOrder.call(booking: b, idempotency_key: "a")
    expect(Payments::CreateOrder.call(booking: b, idempotency_key: "b")).to eq(first)
    deliver_webhook(webhook_body(first))
    expect(code_of { Payments::CreateOrder.call(booking: b.reload, idempotency_key: "c") }).to eq("nothing_to_pay")
    expect(code_of { Payments::CreateOrder.call(booking: booked!, idempotency_key: "d") }).to eq("nothing_to_pay") # not done yet
  end

  it "collects the visit fee after a rejected final price" do
    b = booked!(kind: "inspection")
    act!(b, :schedule, params: { scheduled_at: soon })
    act!(b, :check_in)
    act!(b, :final_quotation, params: lines(300_000))
    act!(b, :reject_final, params: { revision_id: b.reload.pending_revision.public_id })
    payment = pay_online!(b.reload)
    expect(payment).to have_attributes(amount_minor: 19_900, commission_minor: 1_990)
    expect(b.reload).to have_attributes(status: "closed_after_inspection", outstanding_minor: 0)
  end

  describe "refunds" do
    it "reverses the split in proportion, exactly on a full refund, and marks the booking refunded" do
      b = completed_booking!(amount_minor: 99_999)
      payment = pay_online!(b)
      Refunds::Create.call(payment:, amount_minor: 33_333, reason: "Partly redone", auth: finance)
      expect(payment.reload).to have_attributes(status: "partially_refunded", refunded_minor: 33_333)
      expect(code_of { Refunds::Create.call(payment:, amount_minor: 66_667, reason: "x", auth: finance) }).to eq("refund_too_large")
      Refunds::Create.call(payment:, amount_minor: 66_666, reason: "Rest", auth: finance)

      expect(payment.reload).to be_refunded
      %w[gateway_clearing platform_revenue].each { |k| expect(balance(k)).to eq(0) }
      expect(balance("worker_payable", owner: b.worker_profile)).to eq(0)
      expect(b.reload).to be_refunded
      expect(AdminAction.where(action: "payment.refunded").count).to eq(2)
    end

    it "refuses cash payments and needs a reason" do
      b = completed_booking!
      cash = Payments::RecordCash.call(booking: b, worker: b.worker_profile.user, amount_minor: b.outstanding_minor, idempotency_key: "k")
      expect(code_of { Refunds::Create.call(payment: cash, amount_minor: 1, reason: "x", auth: finance) }).to eq("not_refundable")
      online = pay_online!(completed_booking!)
      expect(code_of { Refunds::Create.call(payment: online, amount_minor: 1, reason: " ", auth: finance) }).to eq("reason_required")
    end

    it "completes once even if the refund webhook arrives after an instant refund" do
      payment = pay_online!(completed_booking!)
      refund = Refunds::Create.call(payment:, amount_minor: 1_000, reason: "Goodwill", auth: finance)
      body = { event: "refund.processed", payload: { refund: { entity: { id: refund.provider_refund_id, amount: 1_000 } } } }.to_json
      2.times { deliver_webhook(body) }
      expect(payment.reload.refunded_minor).to eq(1_000)
      expect(Ledger::Transaction.where(kind: "refund_processed").count).to eq(1)
    end
  end

  describe "payouts" do
    it "nets commission owed on cash jobs before paying out, and never pays more than is held" do
      worker_booking = completed_booking!(amount_minor: 100_000)
      worker = worker_booking.worker_profile
      pay_online!(worker_booking) # holds 90,000 for the worker
      cash_job = booked!(amount_minor: 40_000)
      cash_job.update_columns(worker_profile_id: worker.id)
      act!(cash_job, :schedule, params: { scheduled_at: soon })
      act!(cash_job, :start)
      act!(cash_job, :complete)
      Payments::RecordCash.call(booking: cash_job.reload, worker: worker.user, amount_minor: 40_000, idempotency_key: "c") # owes 4,000

      expect(Payouts::Balance.call(worker)).to have_attributes(payable_minor: 90_000, owed_minor: 4_000, net_minor: 86_000)
      expect(code_of { Payouts::Create.call(worker:, amount_minor: 86_001, reference: "UTR1", auth: finance) }).to eq("payout_too_large")
      Payouts::Create.call(worker:, amount_minor: 86_000, reference: "UTR123", auth: finance)
      expect(Payouts::Balance.call(worker)).to have_attributes(payable_minor: 0, owed_minor: 0, net_minor: 0)
      expect(balance("gateway_clearing")).to eq(100_000 - 86_000)
      expect(AdminAction.last).to have_attributes(action: "payout.recorded")
    end
  end

  it "numbers invoices without gaps per financial year" do
    travel_to(Time.zone.parse("2027-03-31 19:00 UTC")) { pay_online!(completed_booking!) } # 00:30 on 1 Apr IST: new year
    travel_to(Time.zone.parse("2027-03-31 10:00 UTC")) { pay_online!(completed_booking!) }
    expect(Invoice.order(:id).pluck(:number)).to eq(%w[WK/2027-28/000001 WK/2026-27/000001])
  end
end
