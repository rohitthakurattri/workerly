require "rails_helper"

RSpec.describe "Triage quality", type: :service do
  let!(:mohali) { create(:mohali) }
  let!(:plumber) { create(:plumber) }
  let!(:electrician) { create(:service_category, slug: "electrician", name_i18n: { "en" => "Electrician" }) }

  # A submitted request whose last triage suggested `suggested` (with `confidence`) and whose
  # customer submitted `final`.
  def triaged!(suggested:, final:, confidence: 0.9, version: "triage-v1")
    request = create(:service_request, :ready, service_category: final)
    analysis = AiAnalysis.create!(analysable: request, user: request.customer, use_case: "triage", provider: "fake", model: "m",
                                  prompt_version: version, input_hash: SecureRandom.hex, status: "succeeded",
                                  suggested_category_id: suggested&.id, confidence:, output: {})
    request.update!(triage_analysis: analysis)
    Requests::Submit.call(request:)
    request
  end

  describe Ai::TriageAccuracy do
    it "scores suggestions against what customers submitted, with calibration and confusions" do
      3.times { triaged!(suggested: plumber, final: plumber) }
      triaged!(suggested: plumber, final: electrician, confidence: 0.7)
      triaged!(suggested: electrician, final: electrician, confidence: 0.5)
      triaged!(suggested: nil, final: electrician, confidence: 0.0)
      create(:service_request, :open) # never triaged

      r = described_class.call(from: 1.hour.ago, to: 1.hour.from_now)
      expect(r).to include(submitted: 7, triaged: 6, coverage: 0.857, accuracy: 0.667, no_suggestion: 1)
      expect(r[:preselected]).to eq(count: 4, share: 0.667, accuracy: 0.75)
      expect(r[:calibration].map { |b| [ b[:count], b[:accuracy] ] }).to eq([ [ 0, nil ], [ 1, 1.0 ], [ 1, 0.0 ], [ 3, 1.0 ] ])
      expect(r[:categories]).to include({ slug: "plumber", requests: 3, suggested: 4, recall: 1.0, precision: 0.75 },
                                        { slug: "electrician", requests: 3, suggested: 1, recall: 0.333, precision: 1.0 })
      expect(r[:confusions]).to eq([ { suggested: "plumber", chosen: "electrician", count: 1 } ])
      expect(r[:versions]).to eq([ { prompt_version: "triage-v1", model: "m", triaged: 6, accuracy: 0.667 } ])
    end
  end

  describe Ai::TriageEval do
    it "runs the labelled set through the adapter without touching the AI log, and the keyword baseline clears the bar" do
      %w[carpenter ac-repair painter appliance-repair].each { |slug| create(:service_category, slug:, name_i18n: { "en" => slug.titleize }) }
      report = described_class.call(adapter: Adapters::Ai::Fake.new)
      expect(report.total).to be >= 30
      expect(report.accuracy).to be >= 0.8
      expect(report.errors).to be_empty
      expect(AiAnalysis.count).to eq(0)
    end
  end
end

RSpec.describe "Admin AI quality", type: :request do
  let!(:mohali) { create(:mohali) }

  it "is admin only and defaults to the last 30 days" do
    get("/api/v1/admin/ai/quality", headers: staff_headers_for(create(:user, :admin), role: "admin"))
    expect(response).to have_http_status(:ok)
    expect(json["data"]).to include("submitted" => 0, "accuracy" => nil)
    expect(Time.zone.parse(json.dig("data", "to")) - Time.zone.parse(json.dig("data", "from"))).to eq(30.days)

    get("/api/v1/admin/ai/quality", headers: staff_headers_for(create(:user, :support), role: "support"))
    expect(response).to have_http_status(:forbidden)
  end
end
