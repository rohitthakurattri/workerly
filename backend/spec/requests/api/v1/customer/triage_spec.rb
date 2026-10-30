require "rails_helper"

RSpec.describe "AI triage", type: :request do
  let!(:plumber) { create(:plumber) }
  let!(:electrician) { create(:service_category, slug: "electrician", name_i18n: { "en" => "Electrician" }) }
  let(:user) { create(:user) }
  let(:headers) { auth_headers_for(user) }
  let(:request_record) { create(:service_request, customer: user, description: "Kitchen tap leaking, pipe drips under the sink") }

  def triage(record = request_record) = post("/api/v1/customer/service_requests/#{record.public_id}/triage", headers:)

  it "suggests a category, summary and follow-up questions, and logs the call" do
    triage
    expect(response).to have_http_status(:ok)
    expect(json["data"]).to include("confidence" => 0.9, "needs_confirmation" => false, "safety_flag" => false)
    expect(json.dig("data", "suggested_category", "slug")).to eq("plumber")
    expect(json.dig("data", "questions")).to be_present

    analysis = AiAnalysis.last
    expect(analysis).to have_attributes(use_case: "triage", provider: "fake", status: "succeeded", user:,
                                        analysable: request_record, suggested_category: plumber, prompt_version: start_with("triage-"))
    expect(request_record.reload).to have_attributes(triage_analysis: analysis, service_category: nil) # suggestion only
    expect(request_record.ai_summary).to be_present
  end

  it "records whether the customer kept the suggestion" do
    triage
    patch("/api/v1/customer/service_requests/#{request_record.public_id}", params: { category: "plumber" }.to_json, headers:)
    expect(json.dig("data", "category_source")).to eq("ai")
    patch("/api/v1/customer/service_requests/#{request_record.public_id}", params: { category: "electrician" }.to_json, headers:)
    expect(json.dig("data", "category_source")).to eq("customer")
  end

  it "asks the customer to confirm when the text is ambiguous" do
    triage(create(:service_request, customer: user, description: "Something is broken at home, please help"))
    expect(json["data"]).to include("suggested_category" => nil, "needs_confirmation" => true)
  end

  it "flags possible danger" do
    triage(create(:service_request, customer: user, description: "Switch board is sparking and there is a burning smell"))
    expect(json["data"]).to include("safety_flag" => true, "urgency" => "asap")
    expect(json.dig("data", "suggested_category", "slug")).to eq("electrician")
  end

  it "reuses the answer for identical input instead of calling the provider again" do
    triage
    expect_any_instance_of(Adapters::Ai::Fake).not_to receive(:complete)
    triage
    expect(AiAnalysis.order(:id).pluck(:cached)).to eq([ false, true ])
  end

  it "returns ai_unavailable when the flag is off" do
    with_config(ai_triage_enabled: false)
    triage
    expect([ response.status, error_code ]).to eq([ 503, "ai_unavailable" ])
  end

  it "returns ai_unavailable when the provider fails, and logs the failure" do
    allow_any_instance_of(Adapters::Ai::Fake).to receive(:complete).and_raise(Adapters::Ai::Error.new(:timeout))
    triage
    expect([ response.status, error_code ]).to eq([ 503, "ai_unavailable" ])
    expect(AiAnalysis.last).to have_attributes(status: "failed", error_code: "timeout")
  end

  it "needs some text or a photo" do
    triage(create(:service_request, customer: user, description: "tap"))
    expect(error_code).to eq("nothing_to_analyse")
  end

  it "only works on the customer's own drafts" do
    triage(create(:service_request))
    expect(response).to have_http_status(:not_found)
    triage(create(:service_request, :open, customer: user))
    expect(error_code).to eq("request_locked")
  end

  it "includes the latest suggestion when the draft is reloaded" do
    triage
    get("/api/v1/customer/service_requests/#{request_record.public_id}", headers:)
    expect(json.dig("data", "triage", "suggested_category", "slug")).to eq("plumber")
  end
end
