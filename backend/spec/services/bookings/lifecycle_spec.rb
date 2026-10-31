require "rails_helper"

RSpec.describe "Booking lifecycle", type: :service do
  let!(:mohali) { create(:mohali) }

  def code_of
    yield
    nil
  rescue ApplicationError => e
    e.code
  end

  it "runs a fixed-price job end to end and fulfils the request" do
    b = booked!
    act!(b, :schedule, params: { scheduled_at: soon })
    expect(b.reload).to have_attributes(status: "scheduled", scheduled_at: be_present)
    act!(b, :start)
    expect(b.reload).to have_attributes(status: "in_progress", started_at: be_present, checked_in_at: be_present)
    act!(b, :complete)
    expect(b.reload).to have_attributes(status: "completed", approved_total_minor: 95_000)
    expect(b.service_request.reload).to be_fulfilled
    expect(b.status_histories.map(&:to_status)).to eq(%w[confirmed scheduled in_progress completed])
    expect(b.status_histories.last.metadata).to include("event" => "complete")
  end

  it "runs an inspection job: visit fee, final price approved separately, fee taken off the bill" do
    b = booked!(kind: "inspection")
    expect(b.approved_total_minor).to eq(19_900)
    act!(b, :schedule, params: { scheduled_at: soon })
    expect(b.reload).to be_inspection_scheduled
    act!(b, :check_in)
    act!(b, :final_quotation, params: lines(150_000))
    expect(b.reload).to have_attributes(status: "awaiting_final_approval", approved_total_minor: 19_900)
    expect(b.pending_revision).to have_attributes(stage: "final", total_minor: 150_000)

    act!(b, :approve_final, params: { revision_id: b.pending_revision.public_id })
    expect(b.reload).to have_attributes(status: "scheduled", approved_total_minor: 150_000, pending_revision: nil)
    act!(b, :start)
    act!(b, :complete)
    expect(b.reload.approved_total_minor).to eq(150_000)
  end

  it "adds the fee on top when INSPECTION_FEE_ADJUSTED is off" do
    with_config(inspection_fee_adjusted: false)
    b = booked!(kind: "inspection")
    act!(b, :schedule, params: { scheduled_at: soon })
    act!(b, :check_in)
    act!(b, :final_quotation, params: lines(150_000))
    act!(b, :approve_final, params: { revision_id: b.reload.pending_revision.public_id })
    expect(b.reload.approved_total_minor).to eq(169_900)
  end

  it "closes after a rejected final price: the visit fee is due and the request reopens for the other quotes" do
    b = booked!(kind: "inspection", rivals: 1)
    rival = b.service_request.quotations.where.not(id: b.quotation_id).sole
    expect(rival.reload.decline_reason).to eq("another_accepted")
    act!(b, :schedule, params: { scheduled_at: soon })
    act!(b, :check_in)
    act!(b, :final_quotation, params: lines(400_000))
    act!(b, :reject_final, params: { revision_id: b.reload.pending_revision.public_id })

    expect(b.reload).to have_attributes(status: "closed_after_inspection", approved_total_minor: 19_900)
    expect(b.quotation.reload).to have_attributes(status: "declined", decline_reason: "booking_cancelled")
    expect(rival.reload).to be_submitted
    expect(b.service_request.reload).to be_quoting
    expect(Bookings::RequestReopenedJob).to have_been_enqueued
    # …and the customer can book the other quote.
    expect { Quotations::Accept.call(quotation: rival, version: 1, customer: b.customer) }.to change(Booking, :count).by(1)
  end

  it "handles extra charges: nothing is owed until the customer approves, a rejection adds nothing" do
    b = booked!
    act!(b, :schedule, params: { scheduled_at: soon })
    act!(b, :start)
    act!(b, :change_order, params: lines(20_000))
    expect(b.reload).to have_attributes(status: "awaiting_change_approval", approved_total_minor: 95_000)
    expect(code_of { act!(b, :complete) }).to eq("invalid_transition")

    act!(b, :reject_change, params: { revision_id: b.pending_revision.public_id })
    expect(b.reload).to have_attributes(status: "in_progress", approved_total_minor: 95_000)
    act!(b, :change_order, params: lines(15_000))
    act!(b, :approve_change, params: { revision_id: b.reload.pending_revision.public_id })
    expect(b.reload.approved_total_minor).to eq(110_000)
    expect(b.approvals.map(&:decision)).to eq(%w[approved rejected approved])
  end

  it "refuses to approve anything but the revision that is waiting, and only once" do
    b = booked!
    act!(b, :schedule, params: { scheduled_at: soon })
    act!(b, :start)
    act!(b, :change_order, params: lines(20_000))
    pending = b.reload.pending_revision
    expect(code_of { act!(b, :approve_change, params: { revision_id: b.quotation.revisions.first.public_id }) }).to eq("revision_not_pending")
    act!(b, :approve_change, params: { revision_id: pending.public_id })
    act!(b, :change_order, params: lines(1_000))
    expect(code_of { act!(b, :approve_change, params: { revision_id: pending.public_id }) }).to eq("revision_not_pending")
  end

  it "cancels before work: nothing owed, request reopens; a cancel after expiry expires the request" do
    b = booked!(rivals: 1)
    act!(b, :cancel, role: "worker", params: { reason: "Fell ill" })
    expect(b.reload).to have_attributes(status: "cancelled", cancelled_by: "worker", cancel_reason: "Fell ill", approved_total_minor: 0)
    expect(b.service_request.reload).to be_quoting

    late = booked!
    travel_to(late.service_request.expires_at + 1.minute) do
      act!(late, :cancel, role: "customer")
      expect(late.service_request.reload).to be_expired
    end
  end

  it "keeps the visit fee when an inspection is cancelled after the worker checked in" do
    b = booked!(kind: "inspection")
    act!(b, :schedule, params: { scheduled_at: soon })
    act!(b, :check_in)
    act!(b, :final_quotation, params: lines(50_000))
    act!(b, :approve_final, params: { revision_id: b.reload.pending_revision.public_id })
    act!(b, :cancel, role: "customer")
    expect(b.reload).to have_attributes(status: "cancelled", approved_total_minor: 19_900)
  end

  it "validates the visit time" do
    b = booked!
    expect(code_of { act!(b, :schedule, params: { scheduled_at: 1.hour.ago.iso8601 }) }).to eq("validation_failed")
    expect(code_of { act!(b, :schedule, params: { scheduled_at: 40.days.from_now.iso8601 }) }).to eq("validation_failed")
    expect(code_of { act!(b, :schedule, params: { scheduled_at: "tomorrow" }) }).to eq("validation_failed")
  end

  it "shares contact details and chat until 48 h after completion" do
    b = booked!
    act!(b, :schedule, params: { scheduled_at: soon })
    act!(b, :start)
    act!(b, :complete)
    expect(b.reload.contact_visible?).to be(true)
    travel(49.hours) do
      expect(b.contact_visible?).to be(false)
      expect(code_of { Bookings::PostMessage.call(booking: b, sender: b.customer, role: "customer", body: "hi") }).to eq("chat_closed")
    end
  end

  describe "reviews and disputes" do
    let!(:booking) do
      booked!.tap do |b|
        act!(b, :schedule, params: { scheduled_at: soon })
        act!(b, :start)
        act!(b, :complete)
      end
    end

    it "updates the worker's rating once per booking" do
      Reviews::Create.call(booking: booking.reload, customer: booking.customer, rating: 4, body: "Neat work")
      expect(booking.worker_profile.reload).to have_attributes(rating_count: 1, rating_avg: 4)
      expect(code_of { Reviews::Create.call(booking:, customer: booking.customer, rating: 5) }).to eq("already_reviewed")
    end

    it "opens a dispute within the window and support resolves it back to completed" do
      dispute = Disputes::Open.call(booking: booking.reload, customer: booking.customer, category: "quality", description: "Still leaking")
      expect(booking.reload).to have_attributes(status: "disputed", status_before_dispute: "completed")
      expect(code_of { Disputes::Open.call(booking:, customer: booking.customer, category: "quality", description: "x") }).to eq("invalid_transition")

      admin = create(:user, :support)
      Disputes::Resolve.call(dispute:, auth: staff_auth(admin, role: "support"), resolution: "Worker revisited and fixed it")
      expect(booking.reload).to have_attributes(status: "completed", status_before_dispute: nil)
      expect(dispute.reload).to have_attributes(status: "resolved", resolved_by: admin)
      expect(AdminAction.last).to have_attributes(action: "dispute.resolved")
    end

    it "closes the dispute window after 7 days" do
      travel(8.days) do
        expect(code_of { Disputes::Open.call(booking: booking.reload, customer: booking.customer, category: "quality", description: "x") })
          .to eq("dispute_window_closed")
      end
    end
  end
end
