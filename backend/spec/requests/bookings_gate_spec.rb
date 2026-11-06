require "rails_helper"

# Phase 6 exit gate: every booking transition is covered by policy + request specs, and no path
# charges more than the customer approved.
RSpec.describe "Bookings exit gate", type: :request do
  let!(:mohali) { create(:mohali) }

  # Every booking endpoint, the event it fires and who may call it.
  WORKER_CALLS = {
    "schedule" => [ :schedule, -> { { scheduled_at: 3.hours.from_now.iso8601 } } ],
    "check_in" => [ :check_in, -> { {} } ],
    "final_quotation" => [ :final_quotation, -> { { items: [ { type: "labour", description: "Fix", quantity: 1, unit: "job", unit_price_minor: 80_000 } ] } } ],
    "start" => [ :start, -> { {} } ],
    "change_orders" => [ :change_order, -> { { items: [ { type: "material", description: "Valve", quantity: 1, unit: "item", unit_price_minor: 5_000 } ] } } ],
    "complete" => [ :complete, -> { {} } ],
    "cancel" => [ :cancel, -> { { reason: "Can't make it" } } ]
  }.freeze

  def with_pending_revision(booking)
    q = booking.quotation
    rev = q.revisions.create!(version: q.current_version + 1, stage: booking.awaiting_final_approval? ? "final" : "change_order",
                              subtotal_minor: 5_000, total_minor: 5_000, currency_code: "INR", created_by: booking.worker_profile.user)
    rev.items.create!(position: 1, item_type: "labour", description: "Extra", quantity: 1, unit: "job", unit_price_minor: 5_000, amount_minor: 5_000)
    q.update_columns(current_version: rev.version)
    booking.update_columns(pending_revision_id: rev.id)
    rev
  end

  def put_in(booking, status)
    booking.update_columns(status:, pending_revision_id: nil, completed_at: status.in?(%w[completed paid disputed]) ? 1.hour.ago : nil,
                           status_before_dispute: status == "disputed" ? "completed" : nil, started_at: nil)
    booking.service_request.update_columns(status: "booked")
    with_pending_revision(booking.reload) if status.start_with?("awaiting_")
    booking.reload
  end

  def allowed?(event, status, role) = Bookings::Transitions::RULES.fetch(event).then { |r| r[:roles].include?(role) && r[:from].key?(status) }

  describe "transition matrix: every endpoint × every status" do
    Booking::STATUSES.each do |status|
      it "answers correctly from #{status}" do
        booking = booked!(kind: status.match?(/inspect|final/) ? "inspection" : "fixed")
        worker = auth_headers_for(booking.worker_profile.user, role: "worker")
        customer = auth_headers_for(booking.customer)
        admin = staff_headers_for(create(:user, :support), role: "support")

        WORKER_CALLS.each do |path, (event, body)|
          put_in(booking, status)
          post "/api/v1/worker/bookings/#{booking.public_id}/#{path}", params: body.call.to_json, headers: worker
          if allowed?(event, status, "worker")
            expect(response).to have_http_status(:ok), "worker #{path} from #{status}: #{response.body}"
          else
            expect(response).to have_http_status(:conflict), "worker #{path} from #{status}: #{response.body}"
            expect(error_code).to eq("invalid_transition")
          end
        end

        %w[approved rejected].each do |decision|
          put_in(booking, status)
          revision = booking.pending_revision || booking.quotation.revisions.last
          post "/api/v1/customer/bookings/#{booking.public_id}/approvals", params: { revision_id: revision.public_id, decision: }.to_json,
                                                                         headers: customer.merge("Idempotency-Key" => SecureRandom.uuid)
          event = :"#{decision == 'approved' ? 'approve' : 'reject'}_#{status == 'awaiting_final_approval' ? 'final' : 'change'}"
          expected = allowed?(event, status, "customer") ? :ok : :conflict
          expect(response).to have_http_status(expected), "customer #{decision} from #{status}: #{response.body}"
        end

        put_in(booking, status)
        post("/api/v1/customer/bookings/#{booking.public_id}/cancel", params: {}.to_json, headers: customer)
        expect(response).to have_http_status(allowed?(:cancel, status, "customer") ? :ok : :conflict), "customer cancel from #{status}"

        put_in(booking, status)
        post("/api/v1/admin/bookings/#{booking.public_id}/cancel", params: { reason: "Stuck" }.to_json, headers: admin)
        expect(response).to have_http_status(allowed?(:admin_cancel, status, "support") ? :ok : :conflict), "admin cancel from #{status}"
      end
    end
  end

  describe "who may act" do
    let(:booking) { booked! }

    it "lets only the booking's own worker and customer act, in their own role" do
      stranger_worker = create(:worker_profile, :matchable)
      post("/api/v1/worker/bookings/#{booking.public_id}/schedule", params: { scheduled_at: soon }.to_json,
                                                                    headers: auth_headers_for(stranger_worker.user, role: "worker"))
      expect(response).to have_http_status(:not_found)

      post("/api/v1/customer/bookings/#{booking.public_id}/cancel", headers: auth_headers_for(create(:user)))
      expect(response).to have_http_status(:not_found)

      # The customer can't fire worker events, and the worker can't approve prices.
      post("/api/v1/worker/bookings/#{booking.public_id}/complete", headers: auth_headers_for(booking.customer))
      expect(response).to have_http_status(:forbidden)
      post("/api/v1/customer/bookings/#{booking.public_id}/approvals", params: { revision_id: "x", decision: "approved" }.to_json,
                                                                     headers: auth_headers_for(booking.worker_profile.user, role: "worker").merge("Idempotency-Key" => "k" * 10))
      expect(response).to have_http_status(:forbidden)

      booking.worker_profile.update!(suspended_at: Time.current, available: false)
      post("/api/v1/worker/bookings/#{booking.public_id}/schedule", params: { scheduled_at: soon }.to_json,
                                                                    headers: auth_headers_for(booking.worker_profile.user, role: "worker"))
      expect(response).to have_http_status(:forbidden)
      expect(error_code).to eq("worker_suspended")

      post("/api/v1/admin/bookings/#{booking.public_id}/cancel", params: { reason: "x" }.to_json,
                                                                 headers: staff_headers_for(create(:user, :verifier), role: "verifier"))
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "no path charges above approved amounts" do
    it "keeps the amount owed equal to the approved revisions through 300 random actions" do
      rng = Random.new(20_261_031)
      events = Bookings::Transitions::EVENTS - %i[dispute resolve_dispute admin_cancel pay refund]
      bookings = [ booked!, booked!(kind: "inspection"), booked!(amount_minor: 1), booked!(kind: "inspection") ]

      finished = 0
      300.times do
        i = rng.rand(bookings.size)
        if %w[completed cancelled closed_after_inspection].include?(bookings[i].reload.status)
          finished += 1
          bookings[i] = booked!(kind: rng.rand < 0.5 ? "fixed" : "inspection", amount_minor: rng.rand(1..200_000))
        end
        b = bookings[i]
        # Mostly something allowed right now (to go deep into the lifecycle), sometimes anything at all.
        possible = (Bookings::Transitions.available(b, "customer") + Bookings::Transitions.available(b, "worker")).map(&:to_sym) & events
        event = rng.rand < 0.75 && possible.any? ? possible.sample(random: rng) : events.sample(random: rng)
        params = case event
        when :schedule then { scheduled_at: (rng.rand(1..48)).hours.from_now.iso8601 }
        when :final_quotation, :change_order then lines(*Array.new(rng.rand(1..3)) { rng.rand(1..90_000) })
        when :approve_final, :reject_final, :approve_change, :reject_change
                   # Mostly the right revision, sometimes a stale or foreign one.
                   { revision_id: (rng.rand < 0.8 ? b.pending_revision : QuotationRevision.order("RANDOM()").first)&.public_id }
        else {}
        end
        role = rng.rand < 0.85 ? Bookings::Transitions::RULES[event][:roles].first : %w[customer worker].sample(random: rng)
        before = b.approved_total_minor
        begin
          act!(b, event, role:, params:)
        rescue ApplicationError
          expect(b.reload.approved_total_minor).to eq(before) # a refused action never moves money
        end

        b.reload
        approved = b.approvals.select(&:approved?).map(&:quotation_revision)
        expect(b.approved_total_minor).to eq(Bookings::AmountDue.call(b))
        expect(b.approved_total_minor).to be <= approved.sum(&:total_minor)
        expect(b.approvals.map(&:decided_by_id).uniq).to eq([ b.customer_id ])
        if b.pending_revision
          expect(approved).not_to include(b.pending_revision)
        end
      end
      # The walk really went through the lifecycle: prices approved and rejected, jobs finished.
      expect(BookingApproval.where(decision: "rejected").count).to be_positive
      expect(QuotationRevision.where(stage: %w[final change_order]).count).to be_positive
      expect(finished).to be_positive
    end

    it "ignores amounts sent by the worker and needs the customer's approval for every extra rupee" do
      b = booked!
      worker = auth_headers_for(b.worker_profile.user, role: "worker")
      customer = auth_headers_for(b.customer)
      post("/api/v1/worker/bookings/#{b.public_id}/schedule", params: { scheduled_at: soon }.to_json, headers: worker)
      post("/api/v1/worker/bookings/#{b.public_id}/start", headers: worker)
      post "/api/v1/worker/bookings/#{b.public_id}/change_orders",
           params: { items: [ { type: "material", description: "Valve", quantity: 2, unit: "item", unit_price_minor: 5_000, amount_minor: 1 } ],
                     total_minor: 1, approved_total_minor: 999_999 }.to_json, headers: worker
      expect(json.dig("data", "pending_revision", "total", "minor")).to eq(10_000)
      expect(json.dig("data", "approved_total", "minor")).to eq(95_000)

      post("/api/v1/worker/bookings/#{b.public_id}/complete", headers: worker)
      expect(error_code).to eq("invalid_transition")

      key = { "Idempotency-Key" => "approve-#{b.public_id}" }
      body = { revision_id: b.reload.pending_revision.public_id, decision: "approved" }.to_json
      post("/api/v1/customer/bookings/#{b.public_id}/approvals", params: body, headers: customer.merge(key))
      expect(json.dig("data", "approved_total", "minor")).to eq(105_000)
      post("/api/v1/customer/bookings/#{b.public_id}/approvals", params: body, headers: customer.merge(key))
      expect(response.headers["Idempotent-Replayed"]).to eq("true")
      expect(b.approvals.count).to eq(2)

      post("/api/v1/customer/bookings/#{b.public_id}/approvals", params: { revision_id: "x", decision: "approved" }.to_json, headers: customer)
      expect(error_code).to eq("idempotency_key_required")
    end
  end
end
