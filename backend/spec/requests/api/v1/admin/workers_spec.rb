require "rails_helper"

RSpec.describe "Admin: worker verification", type: :request do
  let(:verifier) { create(:user, :verifier, name: "Vera") }
  let(:headers) { staff_headers_for(verifier, role: "verifier") }
  let(:profile) { create(:worker_profile, :pending_review) }

  def decide(as: headers, **body)
    post "/api/v1/admin/workers/#{profile.public_id}/verification", params: body.to_json, headers: as
  end

  def doc_ids = profile.documents.order(:kind).to_h { |d| [ d.kind, d.public_id ] }

  def approve_all_docs = doc_ids.values.map { |id| { id:, status: "approved" } }

  describe "GET /api/v1/admin/workers" do
    it "lists the review queue oldest-submitted first, with cursor pagination" do
      older = create(:worker_profile, :pending_review).tap { |p| p.update!(submitted_at: 2.days.ago) }
      newer = create(:worker_profile, :pending_review).tap { |p| p.update!(submitted_at: 1.hour.ago) }
      create(:worker_profile) # draft, not in queue

      get "/api/v1/admin/workers", params: { filter: { status: "pending_review" }, limit: 1 }, headers: headers
      expect(json["data"].map { |w| w["id"] }).to eq([ older.public_id ])

      get "/api/v1/admin/workers", params: { filter: { status: "pending_review" }, limit: 1, cursor: json.dig("meta", "next_cursor") }, headers: headers
      expect(json["data"].map { |w| w["id"] }).to eq([ newer.public_id ])
      expect(json.dig("meta", "next_cursor")).to be_nil
    end

    it "searches by name or phone" do
      target = create(:worker_profile, user: create(:user, :worker, name: "Gurmeet Kaur"))
      create(:worker_profile)
      get "/api/v1/admin/workers", params: { q: "gurmeet" }, headers: headers
      expect(json["data"].map { |w| w["id"] }).to eq([ target.public_id ])
    end

    it "rejects unknown filters and tampered cursors" do
      get "/api/v1/admin/workers", params: { filter: { status: "bogus" } }, headers: headers
      expect(error_code).to eq("invalid_filter")
      get "/api/v1/admin/workers", params: { cursor: "not-a-cursor" }, headers: headers
      expect(error_code).to eq("invalid_cursor")
    end
  end

  it "shows a worker with documents as short-lived URLs" do
    get "/api/v1/admin/workers/#{profile.public_id}", headers: headers
    expect(json.dig("data", "documents").size).to eq(2)
    expect(json.dig("data", "documents", 0, "file")).to include("url" => be_present, "expires_in" => 300)
    expect(json.dig("data", "user", "phone")).to eq(profile.user.phone_e164)
  end

  it "approves a worker end to end: documents, status, history, audit log and SMS" do
    perform_enqueued_jobs { decide(decision: "approved", documents: approve_all_docs) }

    expect(response).to have_http_status(:ok)
    expect(profile.reload).to have_attributes(verification_status: "approved", approved_at: be_present)
    expect(profile.documents.pluck(:status).uniq).to eq([ "approved" ])
    expect(profile.documents.first.reviewed_by).to eq(verifier)
    expect(profile.verifications.sole).to have_attributes(decision: "approved", admin: verifier)
    expect(AdminAction.sole).to have_attributes(action: "worker.verification.approved", admin: verifier, admin_role: "verifier",
                                                target_type: "WorkerProfile", target_id: profile.id, request_id: be_present)
    expect(Adapters::Sms::Fake.deliveries.last).to have_attributes(to: profile.user.phone_e164, body: /approved/)

    get "/api/v1/worker/leads", headers: auth_headers_for(profile.user, role: "worker")
    expect(response).to have_http_status(:ok)
  end

  it "won't approve until every document is reviewed and the required ones approved" do
    decide(decision: "approved")
    expect(error_code).to eq("documents_pending")

    decide(decision: "approved", documents: [ { id: doc_ids["identity"], status: "approved" }, { id: doc_ids["address"], status: "rejected", reason: "Blurry" } ])
    expect(error_code).to eq("documents_not_approved")
    expect(profile.reload.verification_status).to eq("pending_review")
    expect(profile.documents.pluck(:status)).to all(eq("pending")) # rolled back
  end

  it "requests changes, lets the worker fix them, then approves" do
    decide(decision: "changes_requested", reason: "Address proof is blurry",
           documents: [ { id: doc_ids["identity"], status: "approved" }, { id: doc_ids["address"], status: "rejected", reason: "Blurry" } ])
    expect(profile.reload.verification_status).to eq("changes_requested")

    worker = auth_headers_for(profile.user, role: "worker")
    get "/api/v1/worker/verification", headers: worker
    expect(json.dig("data", "last_decision")).to include("decision" => "changes_requested", "reason" => "Address proof is blurry")
    expect(json.dig("data", "missing")).to eq([ "document_address" ])

    post "/api/v1/worker/documents", headers: multipart_headers(worker),
                                     params: { kind: "address", doc_type: "utility_bill", file: fixture("address.pdf", "application/pdf") }
    post "/api/v1/worker/profile/submit_for_review", headers: worker
    expect(json.dig("data", "verification_status")).to eq("pending_review")

    new_address = profile.documents.find_by(kind: "address", status: "pending").public_id
    decide(decision: "approved", documents: [ { id: new_address, status: "approved" } ])
    expect(profile.reload.verification_status).to eq("approved")
    expect(profile.documents.where(kind: "address").pluck(:status)).to contain_exactly("rejected", "approved")
  end

  it "rejects with a reason and makes it final" do
    decide(decision: "rejected")
    expect(error_code).to eq("reason_required")

    decide(decision: "rejected", reason: "Documents don't match")
    expect(profile.reload.verification_status).to eq("rejected")
    decide(decision: "approved", documents: approve_all_docs)
    expect(error_code).to eq("invalid_transition")
  end

  it "requires a reason for each rejected document" do
    decide(decision: "changes_requested", reason: "x", documents: [ { id: doc_ids["address"], status: "rejected" } ])
    expect(error_code).to eq("reason_required")
  end

  it "ignores document ids from other workers" do
    other = create(:worker_profile, :pending_review)
    decide(decision: "approved", documents: [ { id: other.documents.first.public_id, status: "approved" } ])
    expect(response).to have_http_status(:not_found)
    expect(other.documents.first.reload.status).to eq("pending")
  end

  describe "roles" do
    it "lets support view but not decide" do
      support = create(:user, :support)
      h = staff_headers_for(support, role: "support")
      get "/api/v1/admin/workers/#{profile.public_id}", headers: h
      expect(response).to have_http_status(:ok)
      decide(decision: "approved", documents: approve_all_docs, as: h)
      expect(response).to have_http_status(:forbidden)
    end

    it "keeps finance out of verification" do
      finance = create(:user, :finance)
      get "/api/v1/admin/workers", headers: staff_headers_for(finance, role: "finance")
      expect(response).to have_http_status(:forbidden)
    end

    it "refuses consumer sessions" do
      get "/api/v1/admin/workers", headers: auth_headers_for(create(:user, :worker), role: "worker")
      expect(error_code).to eq("staff_session_required")
    end
  end

  describe "suspension" do
    let(:approved) { create(:worker_profile, :approved).tap { |p| p.update!(available: true) } }
    let(:admin) { create(:user, :admin) }
    let(:admin_headers) { staff_headers_for(admin, role: "admin") }

    it "suspends with a reason, cuts off leads at once, and can reinstate" do
      worker = auth_headers_for(approved.user, role: "worker")

      post "/api/v1/admin/workers/#{approved.public_id}/suspend", params: {}.to_json, headers: admin_headers
      expect(error_code).to eq("reason_required")

      post "/api/v1/admin/workers/#{approved.public_id}/suspend", params: { reason: "Repeated no-shows" }.to_json, headers: admin_headers
      expect(approved.reload).to have_attributes(suspended?: true, available: false, suspension_reason: "Repeated no-shows")
      get "/api/v1/worker/leads", headers: worker
      expect(error_code).to eq("worker_suspended")

      post "/api/v1/admin/workers/#{approved.public_id}/reinstate", params: {}.to_json, headers: admin_headers
      get "/api/v1/worker/leads", headers: worker
      expect(response).to have_http_status(:ok)

      expect(AdminAction.pluck(:action)).to eq(%w[worker.suspended worker.reinstated])
      expect(approved.verifications.pluck(:decision)).to eq(%w[suspended reinstated])
    end

    it "is not allowed for verifiers" do
      post "/api/v1/admin/workers/#{approved.public_id}/suspend", params: { reason: "x" }.to_json, headers: headers
      expect(response).to have_http_status(:forbidden)
    end
  end
end
