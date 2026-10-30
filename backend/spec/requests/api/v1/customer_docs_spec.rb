require "swagger_helper"

# Documents the Phase 3 endpoints (happy path + main error). Behaviour is covered in depth elsewhere.
RSpec.describe "Customer API", type: :request do
  REQUEST_BODY = { type: :object, properties: { data: { "$ref" => "#/components/schemas/service_request" } } }.freeze

  let!(:mohali) { create(:mohali) }
  let!(:plumber) { create(:plumber) }
  let(:user) { create(:user) }
  let(:Authorization) { auth_headers_for(user)["Authorization"] }

  path "/api/v1/customer/addresses" do
    get "Saved addresses (default first)" do
      tags "Customer addresses"
      security [ bearer: [] ]
      parameter name: :Authorization, in: :header, schema: { type: :string }
      response "200", "ok" do
        before { create(:address, user:) }
        schema type: :object, properties: { data: { type: :array, items: { "$ref" => "#/components/schemas/address" } } }
        run_test!
      end
    end

    post "Add an address (the city is derived from the pin)" do
      tags "Customer addresses"
      security [ bearer: [] ]
      consumes "application/json"
      parameter name: :Authorization, in: :header, schema: { type: :string }
      parameter name: :body, in: :body, schema: { type: :object, required: %w[line1 locality pincode lat lng], properties: {
        label: { type: :string }, line1: { type: :string }, line2: { type: :string }, landmark: { type: :string },
        locality: { type: :string }, pincode: { type: :string }, lat: { type: :number }, lng: { type: :number }, is_default: { type: :boolean }
      } }
      response "201", "created" do
        let(:body) { { label: "Home", line1: "House 1234", locality: "Sector 70", pincode: "160071", lat: 30.70, lng: 76.72 } }
        schema type: :object, properties: { data: { "$ref" => "#/components/schemas/address" } }
        run_test!
      end
      response "422", "pin outside the launched cities" do
        let(:body) { { line1: "X", locality: "Y", pincode: "110001", lat: 28.61, lng: 77.21 } }
        schema "$ref" => "#/components/schemas/error"
        run_test!
      end
    end
  end

  path "/api/v1/customer/addresses/{id}" do
    parameter name: :id, in: :path, schema: { type: :string }
    let(:id) { create(:address, user:).public_id }

    patch "Edit an address (submitted requests keep their copy)" do
      tags "Customer addresses"
      security [ bearer: [] ]
      consumes "application/json"
      parameter name: :Authorization, in: :header, schema: { type: :string }
      parameter name: :body, in: :body, schema: { type: :object }
      response "200", "updated" do
        let(:body) { { landmark: "Opposite the park", is_default: true } }
        schema type: :object, properties: { data: { "$ref" => "#/components/schemas/address" } }
        run_test!
      end
    end

    delete "Remove an address (soft delete)" do
      tags "Customer addresses"
      security [ bearer: [] ]
      parameter name: :Authorization, in: :header, schema: { type: :string }
      response "204", "removed" do
        run_test!
      end
    end
  end

  path "/api/v1/customer/service_requests" do
    get "Own requests, newest first" do
      tags "Customer requests"
      security [ bearer: [] ]
      parameter name: :Authorization, in: :header, schema: { type: :string }
      parameter name: "filter[status]", in: :query, required: false, schema: { type: :string, enum: %w[active draft past] }
      parameter name: :cursor, in: :query, required: false, schema: { type: :string }
      response "200", "ok" do
        before { create(:service_request, :open, customer: user) }
        schema type: :object, properties: { data: { type: :array, items: { "$ref" => "#/components/schemas/service_request_summary" } },
                                            meta: { "$ref" => "#/components/schemas/page_meta" } }
        run_test!
      end
    end

    post "Start a draft" do
      tags "Customer requests"
      security [ bearer: [] ]
      consumes "application/json"
      parameter name: :Authorization, in: :header, schema: { type: :string }
      parameter name: :body, in: :body, schema: { type: :object, properties: { description: { type: :string } } }
      response "201", "draft created" do
        let(:body) { { description: "Kitchen tap leaking" } }
        schema REQUEST_BODY
        run_test! { expect(json.dig("data", "missing")).to eq(%w[category address]) }
      end
    end
  end

  path "/api/v1/customer/service_requests/{id}" do
    parameter name: :id, in: :path, schema: { type: :string }
    let(:draft) { create(:service_request, customer: user) }
    let(:id) { draft.public_id }

    get "One request" do
      tags "Customer requests"
      security [ bearer: [] ]
      parameter name: :Authorization, in: :header, schema: { type: :string }
      response "200", "ok" do
        schema REQUEST_BODY
        run_test!
      end
      response "404", "someone else's request" do
        let(:id) { create(:service_request).public_id }
        schema "$ref" => "#/components/schemas/error"
        run_test!
      end
    end

    patch "Edit a draft" do
      tags "Customer requests"
      security [ bearer: [] ]
      consumes "application/json"
      parameter name: :Authorization, in: :header, schema: { type: :string }
      parameter name: :body, in: :body, schema: { type: :object, properties: {
        description: { type: :string }, category: { type: :string }, address: { type: :string },
        urgency: { "$ref" => "#/components/schemas/urgency" }, preferred_from: { type: :string, format: "date-time" },
        preferred_to: { type: :string, format: "date-time" },
        answers: { type: :array, items: { type: :object, properties: { question: { type: :string }, answer: { type: :string } } } }
      } }
      response "200", "updated" do
        let(:body) { { category: "plumber", urgency: "today", answers: [ { question: "Where?", answer: "Kitchen" } ] } }
        schema REQUEST_BODY
        run_test!
      end
      response "403", "already submitted" do
        let(:id) { create(:service_request, :open, customer: user).public_id }
        let(:body) { { description: "Changed" } }
        schema "$ref" => "#/components/schemas/error"
        run_test! { expect(error_code).to eq("request_locked") }
      end
    end

    delete "Discard a draft" do
      tags "Customer requests"
      security [ bearer: [] ]
      parameter name: :Authorization, in: :header, schema: { type: :string }
      response "204", "discarded" do
        run_test!
      end
    end
  end

  path "/api/v1/customer/service_requests/{id}/submit" do
    parameter name: :id, in: :path, schema: { type: :string }
    post "Submit a draft (draft -> open)" do
      tags "Customer requests"
      security [ bearer: [] ]
      parameter name: :Authorization, in: :header, schema: { type: :string }
      response "200", "submitted" do
        let(:id) { create(:service_request, :ready, customer: user).public_id }
        schema REQUEST_BODY
        run_test! { expect(json.dig("data", "status")).to eq("open") }
      end
      response "422", "incomplete" do
        let(:id) { create(:service_request, customer: user).public_id }
        schema "$ref" => "#/components/schemas/error"
        run_test! { expect(json.dig("error", "details", "missing")).to eq(%w[category address]) }
      end
    end
  end

  path "/api/v1/customer/service_requests/{id}/cancel" do
    parameter name: :id, in: :path, schema: { type: :string }
    post "Cancel an open request" do
      tags "Customer requests"
      security [ bearer: [] ]
      consumes "application/json"
      parameter name: :Authorization, in: :header, schema: { type: :string }
      parameter name: :body, in: :body, schema: { type: :object, properties: { reason: { type: :string } } }
      response "200", "cancelled" do
        let(:id) { create(:service_request, :open, customer: user).public_id }
        let(:body) { { reason: "Fixed it myself" } }
        schema REQUEST_BODY
        run_test!
      end
    end
  end

  path "/api/v1/customer/service_requests/{id}/attachments" do
    parameter name: :id, in: :path, schema: { type: :string }
    post "Add a photo (re-encoded to JPEG, EXIF and GPS removed, max 2048 px)" do
      tags "Customer requests"
      security [ bearer: [] ]
      consumes "multipart/form-data"
      parameter name: :Authorization, in: :header, schema: { type: :string }
      parameter name: :file, in: :formData, schema: { type: :string, format: :binary }
      let(:id) { create(:service_request, customer: user).public_id }
      response "201", "added" do
        let(:file) { fixture("id.jpg", "image/jpeg") }
        schema type: :object, properties: { data: { "$ref" => "#/components/schemas/request_photo" } }
        run_test!
      end
    end
  end

  path "/api/v1/customer/service_requests/{id}/triage" do
    parameter name: :id, in: :path, schema: { type: :string }
    post "AI suggestion: category, summary, follow-up questions (behind AI_TRIAGE_ENABLED)" do
      tags "Customer requests"
      security [ bearer: [] ]
      parameter name: :Authorization, in: :header, schema: { type: :string }
      let(:id) { create(:service_request, customer: user, description: "Bathroom tap leaking all night").public_id }
      response "200", "suggestion" do
        schema type: :object, properties: { data: { "$ref" => "#/components/schemas/triage" } }
        run_test!
      end
      response "503", "AI off or failing: the customer picks the category" do
        before { with_config(ai_triage_enabled: false) }
        schema "$ref" => "#/components/schemas/error"
        run_test!
      end
    end
  end
end
