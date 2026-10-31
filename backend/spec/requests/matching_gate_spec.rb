require "rails_helper"

# Phase 4 exit gate: a request in Mohali reaches the right 10 workers within 30 s; out-of-area
# workers never see it. Runs the real chain: submit -> MatchRequestJob -> NotifyWorkerJob -> leads API.
RSpec.describe "Matching exit gate", type: :request do
  let!(:mohali) { create(:mohali) }
  let!(:plumber) { create(:plumber) }

  it "invites the 10 best nearby plumbers, notifies them, and shows the lead to nobody else" do
    near = (1..14).map { |i| create(:worker_profile, :matchable, lat: 30.70 + (i * 0.001), lng: 76.72, radius_m: 5000) }
    outside = [
      create(:worker_profile, :matchable, lat: 30.7333, lng: 76.7794, radius_m: 3000),  # Chandigarh, circle stops short
      create(:worker_profile, :matchable, category: create(:service_category, slug: "painter")), # wrong trade
      create(:worker_profile, :matchable).tap { |w| w.update!(available: false) }               # off duty
    ]
    customer = create(:user)
    draft = create(:service_request, :ready, customer:)

    started = Time.current
    perform_enqueued_jobs do
      post "/api/v1/customer/service_requests/#{draft.public_id}/submit", headers: auth_headers_for(customer)
    end
    elapsed = Time.current - started

    invited = draft.reload.invitations.map(&:worker_profile)
    expect(invited).to eq(near.first(10))
    expect(draft.invitations.map(&:notified_at)).to all(be_present)
    expect(elapsed).to be < 30

    near.first(10).each do |w|
      get "/api/v1/worker/leads", headers: auth_headers_for(w.user, role: "worker")
      expect(json["data"].map { |l| l["id"] }).to eq([ draft.public_id ])
    end
    (near.last(4) + outside).each do |w|
      headers = auth_headers_for(w.user, role: "worker")
      get("/api/v1/worker/leads", headers:)
      expect(json["data"]).to be_empty unless response.status == 403
      get("/api/v1/worker/leads/#{draft.public_id}", headers:)
      expect(response.status).to be_in([ 403, 404 ])
    end
    expect(customer.notifications.last.title).to eq("Your request was sent to 10 nearby workers")
  end
end
