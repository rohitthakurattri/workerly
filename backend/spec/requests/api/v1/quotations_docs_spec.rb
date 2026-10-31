require "swagger_helper"

# Documents the Phase 5 endpoints (happy path + main error). Behaviour is covered in depth elsewhere.
RSpec.describe "Quotations API", type: :request do
  let!(:mohali) { create(:mohali) }
  let(:customer) { create(:user) }
  let!(:matched) { matched_request(workers: 2, customer:) }
  let(:service_request) { matched.first }
  let(:worker) { matched.last.first }
  let(:quotation) { quote!(worker, service_request) }
  let(:booking) { Quotations::Accept.call(quotation:, version: 1, customer:) }

  context "as a worker" do
    let(:Authorization) { auth_headers_for(worker.user, role: "worker")["Authorization"] }

    path "/api/v1/worker/leads/{lead_id}/quotations" do
      parameter name: :lead_id, in: :path, schema: { type: :string }, description: "The request's id"
      post "Send a quote (fixed price, or an inspection visit fee). Prices are computed by the server" do
        tags "Worker quotations"
        security [ bearer: [] ]
        consumes "application/json"
        parameter name: :Authorization, in: :header, schema: { type: :string }
        parameter name: :body, in: :body, schema: { "$ref" => "#/components/schemas/quotation_input" }
        let(:lead_id) { service_request.public_id }
        let(:body) { QuoteHelpers::FIXED }
        response "201", "sent" do
          schema type: :object, properties: { data: { "$ref" => "#/components/schemas/worker_quotation" } }
          run_test!
        end
        response "409", "already quoted, request full or closed" do
          before { quotation }
          schema "$ref" => "#/components/schemas/error"
          run_test! { expect(error_code).to eq("already_quoted") }
        end
        response "422", "invalid lines" do
          let(:body) { { kind: "fixed", items: [] } }
          schema "$ref" => "#/components/schemas/error"
          run_test!
        end
      end
    end

    path "/api/v1/worker/quotations" do
      get "My quotes (newest first)" do
        tags "Worker quotations"
        security [ bearer: [] ]
        parameter name: :Authorization, in: :header, schema: { type: :string }
        parameter name: "filter[status]", in: :query, required: false, schema: { "$ref" => "#/components/schemas/quotation_status" }
        parameter name: :cursor, in: :query, required: false, schema: { type: :string }
        response "200", "ok" do
          before { quotation }
          schema type: :object, properties: { data: { type: :array, items: { "$ref" => "#/components/schemas/worker_quotation" } },
                                              meta: { "$ref" => "#/components/schemas/page_meta" } }
          run_test!
        end
      end
    end

    path "/api/v1/worker/quotations/{id}" do
      parameter name: :id, in: :path, schema: { type: :string }
      let(:id) { quotation.public_id }
      get "One of my quotes" do
        tags "Worker quotations"
        security [ bearer: [] ]
        parameter name: :Authorization, in: :header, schema: { type: :string }
        response "200", "ok" do
          schema type: :object, properties: { data: { "$ref" => "#/components/schemas/worker_quotation" } }
          run_test!
        end
      end
      patch "Revise: send the whole quote again; it becomes a new version" do
        tags "Worker quotations"
        security [ bearer: [] ]
        consumes "application/json"
        parameter name: :Authorization, in: :header, schema: { type: :string }
        parameter name: :body, in: :body, schema: { "$ref" => "#/components/schemas/quotation_input" }
        let(:body) { fixed_quote(80_000) }
        response "200", "revised" do
          schema type: :object, properties: { data: { "$ref" => "#/components/schemas/worker_quotation" } }
          run_test! { expect(json.dig("data", "current_version")).to eq(2) }
        end
        response "409", "accepted, declined, withdrawn or expired" do
          before { booking }
          schema "$ref" => "#/components/schemas/error"
          run_test!
        end
      end
    end

    path "/api/v1/worker/quotations/{id}/withdraw" do
      parameter name: :id, in: :path, schema: { type: :string }
      post "Withdraw a quote that hasn't been accepted" do
        tags "Worker quotations"
        security [ bearer: [] ]
        parameter name: :Authorization, in: :header, schema: { type: :string }
        let(:id) { quotation.public_id }
        response "200", "withdrawn" do
          schema type: :object, properties: { data: { "$ref" => "#/components/schemas/worker_quotation" } }
          run_test!
        end
      end
    end

    path "/api/v1/worker/bookings" do
      get "Jobs I won (newest first)" do
        tags "Worker bookings"
        security [ bearer: [] ]
        parameter name: :Authorization, in: :header, schema: { type: :string }
        response "200", "ok" do
          before { booking }
          schema type: :object, properties: { data: { type: :array, items: { "$ref" => "#/components/schemas/worker_booking" } },
                                              meta: { "$ref" => "#/components/schemas/page_meta" } }
          run_test!
        end
      end
    end

    path "/api/v1/worker/bookings/{id}" do
      parameter name: :id, in: :path, schema: { type: :string }
      get "One job, with the customer's name, phone and full address" do
        tags "Worker bookings"
        security [ bearer: [] ]
        parameter name: :Authorization, in: :header, schema: { type: :string }
        response "200", "ok" do
          let(:id) { booking.public_id }
          schema type: :object, properties: { data: { "$ref" => "#/components/schemas/worker_booking" } }
          run_test!
        end
      end
    end
  end

  context "as a customer" do
    let(:Authorization) { auth_headers_for(customer)["Authorization"] }

    path "/api/v1/customer/service_requests/{service_request_id}/quotations" do
      parameter name: :service_request_id, in: :path, schema: { type: :string }
      get "Quotes on my request (accepted first, then cheapest first)" do
        tags "Customer quotations"
        security [ bearer: [] ]
        parameter name: :Authorization, in: :header, schema: { type: :string }
        let(:service_request_id) { service_request.public_id }
        response "200", "ok" do
          before { quotation }
          schema type: :object, properties: { data: { type: :array, items: { "$ref" => "#/components/schemas/quotation" } } }
          run_test!
        end
      end
    end

    path "/api/v1/customer/quotations/{id}" do
      parameter name: :id, in: :path, schema: { type: :string }
      get "One quote, with its price history" do
        tags "Customer quotations"
        security [ bearer: [] ]
        parameter name: :Authorization, in: :header, schema: { type: :string }
        let(:id) { quotation.public_id }
        response "200", "ok" do
          schema type: :object, properties: { data: { "$ref" => "#/components/schemas/quotation" } }
          run_test!
        end
      end
    end

    path "/api/v1/customer/quotations/{id}/accept" do
      parameter name: :id, in: :path, schema: { type: :string }
      post "Accept the version I saw. Creates the booking; other quotes are declined" do
        tags "Customer quotations"
        security [ bearer: [] ]
        consumes "application/json"
        parameter name: :Authorization, in: :header, schema: { type: :string }
        parameter name: "Idempotency-Key", in: :header, required: true, schema: { type: :string },
                  description: "8–255 chars. A replay returns the stored response with Idempotent-Replayed: true"
        parameter name: :body, in: :body, schema: { type: :object, required: %w[version], properties: { version: { type: :integer } } }
        let(:id) { quotation.public_id }
        let(:"Idempotency-Key") { SecureRandom.uuid }
        let(:body) { { version: 1 } }
        response "201", "booked" do
          schema type: :object, properties: { data: { "$ref" => "#/components/schemas/customer_booking" } }
          run_test!
        end
        response "409", "the quote changed, expired, or the request is already booked" do
          let(:body) { { version: 2 } }
          schema "$ref" => "#/components/schemas/error"
          run_test! { expect(error_code).to eq("quotation_changed") }
        end
      end
    end

    path "/api/v1/customer/quotations/{id}/decline" do
      parameter name: :id, in: :path, schema: { type: :string }
      post "Decline one quote" do
        tags "Customer quotations"
        security [ bearer: [] ]
        consumes "application/json"
        parameter name: :Authorization, in: :header, schema: { type: :string }
        parameter name: :body, in: :body, schema: { type: :object, properties: { reason: { type: :string } } }
        let(:id) { quotation.public_id }
        let(:body) { { reason: "Too expensive" } }
        response "200", "declined" do
          schema type: :object, properties: { data: { "$ref" => "#/components/schemas/quotation" } }
          run_test!
        end
      end
    end

    path "/api/v1/customer/bookings" do
      get "My bookings (newest first)" do
        tags "Customer bookings"
        security [ bearer: [] ]
        parameter name: :Authorization, in: :header, schema: { type: :string }
        response "200", "ok" do
          before { booking }
          schema type: :object, properties: { data: { type: :array, items: { "$ref" => "#/components/schemas/customer_booking" } },
                                              meta: { "$ref" => "#/components/schemas/page_meta" } }
          run_test!
        end
      end
    end

    path "/api/v1/customer/bookings/{id}" do
      parameter name: :id, in: :path, schema: { type: :string }
      get "One booking, with the worker's phone" do
        tags "Customer bookings"
        security [ bearer: [] ]
        parameter name: :Authorization, in: :header, schema: { type: :string }
        let(:id) { booking.public_id }
        response "200", "ok" do
          schema type: :object, properties: { data: { "$ref" => "#/components/schemas/customer_booking" } }
          run_test!
        end
      end
    end
  end
end
