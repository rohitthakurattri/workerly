require "rails_helper"

RSpec.describe "Admin: audit log and categories", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:headers) { staff_headers_for(admin, role: "admin") }

  it "lists audit entries newest first with resolved target ids, admin only" do
    profile = create(:worker_profile, :approved)
    post "/api/v1/admin/workers/#{profile.public_id}/suspend", params: { reason: "Fraud check" }.to_json, headers: headers

    get "/api/v1/admin/audit_logs", params: { filter: { target_type: "WorkerProfile", target_id: profile.public_id } }, headers: headers
    expect(json["data"].sole).to include("action" => "worker.suspended", "target_id" => profile.public_id, "reason" => "Fraud check")

    verifier = create(:user, :verifier)
    get "/api/v1/admin/audit_logs", headers: staff_headers_for(verifier, role: "verifier")
    expect(response).to have_http_status(:forbidden)
  end

  it "creates and deactivates categories with an audit trail" do
    post "/api/v1/admin/categories", headers:, params: { category: { slug: "pest-control", name_i18n: { en: "Pest control", hi: "कीट नियंत्रण" } } }.to_json
    expect(response).to have_http_status(:created)

    patch "/api/v1/admin/categories/pest-control", params: { category: { active: false } }.to_json, headers: headers
    expect(json.dig("data", "active")).to be(false)

    get "/api/v1/categories", headers: json_headers
    expect(json["data"].map { |c| c["slug"] }).not_to include("pest-control")
    expect(AdminAction.pluck(:action)).to eq(%w[category.created category.updated])
  end

  it "requires an English name" do
    post "/api/v1/admin/categories", headers:, params: { category: { slug: "x", name_i18n: { hi: "x" } } }.to_json
    expect(json.dig("error", "details", "field_errors")).to have_key("name_i18n")
  end
end
