require "swagger_helper"

# Documents the Phase 2 endpoints (happy path + main error). Behaviour is covered in depth elsewhere.
RSpec.describe "Workers API", type: :request do
  PROFILE_BODY = { type: :object, properties: { data: { "$ref" => "#/components/schemas/worker_profile" } } }.freeze

  let!(:mohali) { create(:mohali) }
  let!(:plumber) { create(:plumber) }

  path "/api/v1/categories" do
    get "Active service categories (tree)" do
      tags "Catalog"
      response "200", "ok" do
        schema type: :object, properties: { data: { type: :array, items: { "$ref" => "#/components/schemas/category" } } }
        run_test!
      end
    end
  end

  path "/api/v1/cities" do
    get "Launched cities" do
      tags "Catalog"
      response "200", "ok" do
        schema type: :object, properties: { data: { type: :array, items: { "$ref" => "#/components/schemas/city" } } }
        run_test!
      end
    end
  end

  path "/api/v1/worker/registration" do
    post "Become a worker (customer -> worker)" do
      tags "Worker onboarding"
      security [ bearer: [] ]
      consumes "application/json"
      parameter name: :Authorization, in: :header, schema: { type: :string }
      parameter name: :body, in: :body, schema: { type: :object, properties: { name: { type: :string } } }
      let(:Authorization) { auth_headers_for(create(:user))["Authorization"] }
      let(:body) { { name: "Harpreet Singh" } }

      response "201", "registered; returns a worker-role access token" do
        schema type: :object, properties: { data: { type: :object, properties: {
          profile: { "$ref" => "#/components/schemas/worker_profile" }, access_token: { type: :string },
          expires_in: { type: :integer }, active_role: { type: :string }
        } } }
        run_test!
      end
    end
  end

  context "as a worker" do
    let(:profile) { create(:worker_profile) }
    let(:Authorization) { auth_headers_for(profile.user, role: "worker")["Authorization"] }

    path "/api/v1/worker/profile" do
      get "Own worker profile" do
        tags "Worker onboarding"
        security [ bearer: [] ]
        parameter name: :Authorization, in: :header, schema: { type: :string }
        response "200", "ok" do
          schema PROFILE_BODY
          run_test! { expect(json.dig("data", "verification_status")).to eq("draft") }
        end
      end

      patch "Update bio and experience (send multipart with profile[photo] to upload a photo)" do
        tags "Worker onboarding"
        security [ bearer: [] ]
        consumes "application/json"
        parameter name: :Authorization, in: :header, schema: { type: :string }
        parameter name: :body, in: :body, schema: { type: :object, properties: {
          profile: { type: :object, properties: { bio: { type: :string }, experience_years: { type: :integer } } }
        } }
        response "200", "updated" do
          let(:body) { { profile: { bio: "Pipes and taps", experience_years: 3 } } }
          schema PROFILE_BODY
          run_test!
        end
      end
    end

    path "/api/v1/worker/skills" do
      put "Replace skills" do
        tags "Worker onboarding"
        security [ bearer: [] ]
        consumes "application/json"
        parameter name: :Authorization, in: :header, schema: { type: :string }
        parameter name: :body, in: :body, schema: { type: :object, required: %w[skills], properties: {
          skills: { type: :array, items: { type: :object, required: %w[category], properties: { category: { type: :string }, experience_years: { type: :integer } } } }
        } }
        response "200", "replaced" do
          let(:body) { { skills: [ { category: "plumber", experience_years: 4 } ] } }
          run_test!
        end
        response "422", "unknown category" do
          let(:body) { { skills: [ { category: "astrology" } ] } }
          schema "$ref" => "#/components/schemas/error"
          run_test!
        end
      end
    end

    path "/api/v1/worker/service_areas" do
      post "Add a service area (max 3)" do
        tags "Worker onboarding"
        security [ bearer: [] ]
        consumes "application/json"
        parameter name: :Authorization, in: :header, schema: { type: :string }
        parameter name: :body, in: :body, schema: { type: :object, required: %w[city lat lng radius_m], properties: {
          city: { type: :string }, lat: { type: :number }, lng: { type: :number }, radius_m: { type: :integer, minimum: 500, maximum: 50_000 }, label: { type: :string }
        } }
        response "201", "created" do
          let(:body) { { city: "mohali", lat: 30.70, lng: 76.72, radius_m: 5000 } }
          schema type: :object, properties: { data: { "$ref" => "#/components/schemas/service_area" } }
          run_test!
        end
      end
    end

    path "/api/v1/worker/documents" do
      post "Upload a verification document (JPEG/PNG/WebP/HEIC/PDF, max 10 MB)" do
        tags "Worker onboarding"
        security [ bearer: [] ]
        consumes "multipart/form-data"
        parameter name: :Authorization, in: :header, schema: { type: :string }
        parameter name: :kind, in: :formData, schema: { type: :string, enum: %w[identity address trade] }
        parameter name: :doc_type, in: :formData, schema: { type: :string }
        parameter name: :number_last4, in: :formData, schema: { type: :string }
        parameter name: :file, in: :formData, schema: { type: :string, format: :binary }
        let(:kind) { "identity" }
        let(:doc_type) { "pan" }
        let(:number_last4) { "123F" }
        let(:file) { fixture("id.jpg", "image/jpeg") }
        response "201", "uploaded" do
          schema type: :object, properties: { data: { "$ref" => "#/components/schemas/worker_document" } }
          run_test!
        end
      end
    end

    path "/api/v1/worker/profile/submit_for_review" do
      post "Submit for verification" do
        tags "Worker onboarding"
        security [ bearer: [] ]
        parameter name: :Authorization, in: :header, schema: { type: :string }
        response "200", "submitted" do
          let(:profile) { create(:worker_profile, :complete) }
          schema PROFILE_BODY
          run_test! { expect(json.dig("data", "verification_status")).to eq("pending_review") }
        end
        response "422", "incomplete (details.missing lists what's left)" do
          schema "$ref" => "#/components/schemas/error"
          run_test!
        end
      end
    end

    path "/api/v1/worker/leads" do
      get "Leads (approved workers only)" do
        tags "Worker leads"
        security [ bearer: [] ]
        parameter name: :Authorization, in: :header, schema: { type: :string }
        response "200", "ok" do
          let(:profile) { create(:worker_profile, :approved) }
          run_test!
        end
        response "403", "not verified" do
          schema "$ref" => "#/components/schemas/error"
          run_test! { expect(error_code).to eq("worker_not_verified") }
        end
      end
    end
  end

  context "as staff" do
    let(:verifier) { create(:user, :verifier) }
    let(:Authorization) { staff_headers_for(verifier, role: "verifier")["Authorization"] }
    let(:worker) { create(:worker_profile, :pending_review) }

    path "/api/v1/admin/workers" do
      get "Worker list / review queue" do
        tags "Admin"
        security [ bearer: [] ]
        parameter name: :Authorization, in: :header, schema: { type: :string }
        parameter name: "filter[status]", in: :query, required: false, schema: { "$ref" => "#/components/schemas/verification_status" }
        parameter name: :q, in: :query, required: false, schema: { type: :string }
        parameter name: :cursor, in: :query, required: false, schema: { type: :string }
        parameter name: :limit, in: :query, required: false, schema: { type: :integer }
        let(:"filter[status]") { "pending_review" }
        response "200", "ok" do
          before { worker }
          schema type: :object, properties: { data: { type: :array, items: { "$ref" => "#/components/schemas/admin_worker_summary" } },
                                              meta: { "$ref" => "#/components/schemas/page_meta" } }
          run_test!
        end
      end
    end

    path "/api/v1/admin/workers/{id}" do
      get "Worker detail with documents" do
        tags "Admin"
        security [ bearer: [] ]
        parameter name: :Authorization, in: :header, schema: { type: :string }
        parameter name: :id, in: :path, schema: { type: :string }
        let(:id) { worker.public_id }
        response "200", "ok" do
          schema type: :object, properties: { data: { "$ref" => "#/components/schemas/admin_worker_detail" } }
          run_test!
        end
      end
    end

    path "/api/v1/admin/workers/{id}/verification" do
      post "Decide on a submitted worker" do
        tags "Admin"
        security [ bearer: [] ]
        consumes "application/json"
        parameter name: :Authorization, in: :header, schema: { type: :string }
        parameter name: :id, in: :path, schema: { type: :string }
        parameter name: :body, in: :body, schema: { type: :object, required: %w[decision], properties: {
          decision: { type: :string, enum: %w[approved changes_requested rejected] }, reason: { type: :string },
          documents: { type: :array, items: { type: :object, required: %w[id status], properties: {
            id: { type: :string }, status: { type: :string, enum: %w[approved rejected] }, reason: { type: :string }
          } } }
        } }
        let(:id) { worker.public_id }
        response "200", "approved" do
          let(:body) { { decision: "approved", documents: worker.documents.map { |d| { id: d.public_id, status: "approved" } } } }
          schema type: :object, properties: { data: { "$ref" => "#/components/schemas/admin_worker_detail" } }
          run_test!
        end
        response "422", "documents still pending" do
          let(:body) { { decision: "approved" } }
          schema "$ref" => "#/components/schemas/error"
          run_test!
        end
      end
    end

    path "/api/v1/admin/workers/{id}/suspend" do
      post "Suspend a worker (admin, support)" do
        tags "Admin"
        security [ bearer: [] ]
        consumes "application/json"
        parameter name: :Authorization, in: :header, schema: { type: :string }
        parameter name: :id, in: :path, schema: { type: :string }
        parameter name: :body, in: :body, schema: { type: :object, required: %w[reason], properties: { reason: { type: :string } } }
        let(:id) { create(:worker_profile, :approved).public_id }
        let(:body) { { reason: "No-shows" } }
        response "200", "suspended" do
          let(:Authorization) { staff_headers_for(create(:user, :admin), role: "admin")["Authorization"] }
          run_test!
        end
        response "403", "verifiers can't suspend" do
          schema "$ref" => "#/components/schemas/error"
          run_test!
        end
      end
    end

    path "/api/v1/admin/audit_logs" do
      get "Audit log (admin)" do
        tags "Admin"
        security [ bearer: [] ]
        parameter name: :Authorization, in: :header, schema: { type: :string }
        response "200", "ok" do
          let(:Authorization) { staff_headers_for(create(:user, :admin), role: "admin")["Authorization"] }
          run_test!
        end
      end
    end
  end
end
