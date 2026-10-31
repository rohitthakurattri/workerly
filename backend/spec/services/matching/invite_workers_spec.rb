require "rails_helper"

RSpec.describe Matching::InviteWorkers, type: :service do
  let!(:mohali) { create(:mohali) }
  let!(:plumber) { create(:plumber) }
  # Request at Sector 70, Mohali.
  let(:request) { create(:service_request, :open) }

  def invited = described_class.call(request).map(&:worker_profile)
  def worker(**opts) = create(:worker_profile, :matchable, **opts)

  describe "eligibility" do
    it "invites approved, available, skilled workers whose area covers the request" do
      near = worker
      expect(invited).to eq([ near ])
      expect(request.reload).to have_attributes(invited_count: 1, matched_at: be_present)
    end

    it "never invites workers whose circle does not reach the request" do
      worker(lat: 30.7333, lng: 76.7794, radius_m: 3000) # Chandigarh Sector 17, ~6.8 km away
      worker(lat: 30.7333, lng: 76.7794, radius_m: 8000).tap { |w| @reaches = w }
      expect(invited).to eq([ @reaches ])
    end

    it "uses the nearest of a worker's areas" do
      w = worker(lat: 30.7333, lng: 76.7794, radius_m: 8000)
      w.service_areas.create!(city: mohali, center: GeoPoint.point(lat: 30.7005, lng: 76.7205), radius_m: 2000)
      described_class.call(request)
      expect(request.invitations.first.distance_m).to be < 100
    end

    {
      "the wrong skill" => -> { create(:worker_profile, :matchable, category: create(:service_category, slug: "painter")) },
      "unavailable" => -> { create(:worker_profile, :matchable).tap { |w| w.update!(available: false) } },
      "suspended" => -> { create(:worker_profile, :matchable).tap { |w| w.update!(available: false, suspended_at: Time.current) } },
      "not approved" => -> { create(:worker_profile, :matchable).tap { |w| w.update!(available: false, verification_status: "pending_review") } },
      "a suspended account" => -> { create(:worker_profile, :matchable).tap { |w| w.user.update!(status: "suspended") } },
      "the customer themselves" => -> { create(:worker_profile, :matchable, user: request.customer.tap { |u| u.grant_role!(:worker) }) }
    }.each do |reason, build|
      it "skips workers who are #{reason}" do
        instance_exec(&build)
        expect(invited).to be_empty
        expect(request.reload.invited_count).to eq(0)
      end
    end
  end

  describe "ranking and fan-out" do
    it "invites only the best 10, closest first when everything else is equal" do
      workers = (1..12).map { |i| worker(lat: 30.70 + (i * 0.002), lng: 76.72) } # ~220 m apart, northwards
      expect(invited).to eq(workers.first(10))
      expect(request.invitations.pluck(:rank)).to eq((1..10).to_a)
    end

    it "honours MATCH_FANOUT" do
      with_config(match_fanout: 3)
      5.times { worker }
      expect(invited.size).to eq(3)
    end

    it "gives workers who got few leads lately a fair share" do
      busy = worker(lat: 30.7005, lng: 76.7201)
      fresh = worker(lat: 30.7015, lng: 76.7201) # slightly further away
      other = create(:service_request, :open)
      12.times { create(:service_request, :open).invitations.create!(worker_profile: busy, rank: 1, rank_score: 0.5, distance_m: 100) }
      other.invitations.create!(worker_profile: fresh, rank: 1, rank_score: 0.5, distance_m: 100)
      expect(invited).to eq([ fresh, busy ])
    end

    it "prefers well-rated workers" do
      average = worker(lat: 30.7005, lng: 76.7201)
      great = worker(lat: 30.7010, lng: 76.7201)
      great.update!(rating_avg: 4.9, rating_count: 40)
      average.update!(rating_avg: 3.2, rating_count: 40)
      expect(invited).to eq([ great, average ])
    end
  end

  it "runs once per request, even if the job runs twice" do
    worker
    described_class.call(request)
    expect(described_class.call(request)).to eq([])
    expect(request.invitations.count).to eq(1)
  end

  it "doesn't match drafts or cancelled requests" do
    worker
    Requests::Cancel.call(request:)
    expect(invited).to be_empty
  end

  it "queues a notification per invited worker and one for the customer" do
    2.times { worker }
    expect { described_class.call(request) }
      .to have_enqueued_job(Matching::NotifyWorkerJob).exactly(2).times
      .and have_enqueued_job(Matching::CustomerMatchedJob).with(request.id)
  end

  it "starts automatically when a request is submitted" do
    draft = create(:service_request, :ready)
    expect { Requests::Submit.call(request: draft) }.to have_enqueued_job(Matching::MatchRequestJob).with(draft.id).on_queue("critical")
  end
end
