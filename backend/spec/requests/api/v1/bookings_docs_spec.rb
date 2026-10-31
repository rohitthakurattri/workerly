require "swagger_helper"

# Documents the Phase 6 endpoints (happy path + main error). Behaviour is covered in
# spec/requests/bookings_gate_spec.rb and spec/requests/api/v1/bookings_spec.rb.
RSpec.describe "Bookings lifecycle API", type: :request do
  let!(:mohali) { create(:mohali) }
  let(:booking) { booked! }
  let(:id) { booking.public_id }

  def self.booking_response(schema_name)
    schema type: :object, properties: { data: { "$ref" => "#/components/schemas/#{schema_name}" } }
  end

  context "as the worker" do
    let(:Authorization) { auth_headers_for(booking.worker_profile.user, role: "worker")["Authorization"] }

    {
      "schedule" => [ "Set or change the visit time", { scheduled_at: { type: :string } }, -> { { scheduled_at: soon } }, nil ],
      "check_in" => [ "Arrived for the inspection", nil, -> { {} }, ->(b) { act!(b, :schedule, params: { scheduled_at: soon }) } ],
      "start" => [ "Start the work", nil, -> { {} }, ->(b) { act!(b, :schedule, params: { scheduled_at: soon }) } ],
      "change_orders" => [ "Ask for extra charges (needs the customer's approval)", nil, -> { lines(5_000) },
                           ->(b) { act!(b, :schedule, params: { scheduled_at: soon }) && act!(b, :start) } ],
      "complete" => [ "Mark the work done", nil, -> { {} }, ->(b) { act!(b, :schedule, params: { scheduled_at: soon }) && act!(b, :start) } ],
      "cancel" => [ "Cancel before the work starts", { reason: { type: :string } }, -> { { reason: "Unwell" } }, nil ]
    }.each do |path_name, (summary, props, body_fn, setup)|
      path "/api/v1/worker/bookings/{id}/#{path_name}" do
        parameter name: :id, in: :path, schema: { type: :string }
        post summary do
          tags "Worker bookings"
          security [ bearer: [] ]
          consumes "application/json"
          parameter name: :Authorization, in: :header, schema: { type: :string }
          parameter name: :body, in: :body, schema: props ? { type: :object, properties: props } : { "$ref" => "#/components/schemas/quotation_input" }
          let(:body) { instance_exec(&body_fn) }
          let(:booking) { booked!(kind: path_name == "check_in" ? "inspection" : "fixed") }
          before { setup && instance_exec(booking, &setup) }
          response "200", "done" do
            booking_response("worker_booking")
            run_test!
          end
          response "409", "not possible in the booking's current status" do
            before { booking.update_columns(status: "completed") }
            schema "$ref" => "#/components/schemas/error"
            run_test! { expect(error_code).to eq("invalid_transition") }
          end
        end
      end
    end

    path "/api/v1/worker/bookings/{id}/final_quotation" do
      parameter name: :id, in: :path, schema: { type: :string }
      post "Send the final price after an inspection" do
        tags "Worker bookings"
        security [ bearer: [] ]
        consumes "application/json"
        parameter name: :Authorization, in: :header, schema: { type: :string }
        parameter name: :body, in: :body, schema: { "$ref" => "#/components/schemas/quotation_input" }
        let(:booking) { booked!(kind: "inspection").tap { |b| act!(b, :schedule, params: { scheduled_at: soon }) && act!(b, :check_in) } }
        let(:body) { lines(120_000) }
        response "200", "waiting for the customer's approval" do
          booking_response("worker_booking")
          run_test! { expect(json.dig("data", "status")).to eq("awaiting_final_approval") }
        end
      end
    end

    path "/api/v1/worker/bookings/{id}/messages" do
      parameter name: :id, in: :path, schema: { type: :string }
      get "Chat messages" do
        tags "Booking chat"
        security [ bearer: [] ]
        parameter name: :Authorization, in: :header, schema: { type: :string }
        response "200", "ok" do
          schema type: :object, properties: { data: { type: :array, items: { "$ref" => "#/components/schemas/message" } } }
          run_test!
        end
      end
      post "Send a chat message (open until 48 h after completion)" do
        tags "Booking chat"
        security [ bearer: [] ]
        consumes "application/json"
        parameter name: :Authorization, in: :header, schema: { type: :string }
        parameter name: :body, in: :body, schema: { type: :object, required: %w[body], properties: { body: { type: :string } } }
        let(:body) { { body: "On my way" } }
        response "201", "sent" do
          schema type: :object, properties: { data: { "$ref" => "#/components/schemas/message" } }
          run_test!
        end
      end
    end

    path "/api/v1/worker/reviews" do
      get "Reviews customers left (newest first)" do
        tags "Worker bookings"
        security [ bearer: [] ]
        parameter name: :Authorization, in: :header, schema: { type: :string }
        response "200", "ok" do
          run_test!
        end
      end
    end
  end

  context "as the customer" do
    let(:Authorization) { auth_headers_for(booking.customer)["Authorization"] }

    path "/api/v1/customer/bookings/{id}/approvals" do
      parameter name: :id, in: :path, schema: { type: :string }
      post "Approve or reject the price waiting for me (final price or extra charges)" do
        tags "Customer bookings"
        security [ bearer: [] ]
        consumes "application/json"
        parameter name: :Authorization, in: :header, schema: { type: :string }
        parameter name: "Idempotency-Key", in: :header, required: true, schema: { type: :string }
        parameter name: :body, in: :body, schema: { type: :object, required: %w[revision_id decision],
                                                    properties: { revision_id: { type: :string }, decision: { type: :string, enum: %w[approved rejected] } } }
        let(:"Idempotency-Key") { SecureRandom.uuid }
        before { act!(booking, :schedule, params: { scheduled_at: soon }) && act!(booking, :start) && act!(booking, :change_order, params: lines(5_000)) }
        let(:body) { { revision_id: booking.reload.pending_revision.public_id, decision: "approved" } }
        response "200", "decided" do
          booking_response("customer_booking")
          run_test! { expect(json.dig("data", "approved_total", "minor")).to eq(100_000) }
        end
        response "409", "that revision isn't the one waiting" do
          let(:body) { { revision_id: booking.quotation.revisions.first.public_id, decision: "approved" } }
          schema "$ref" => "#/components/schemas/error"
          run_test! { expect(error_code).to eq("revision_not_pending") }
        end
      end
    end

    path "/api/v1/customer/bookings/{id}/cancel" do
      parameter name: :id, in: :path, schema: { type: :string }
      post "Cancel before the work starts" do
        tags "Customer bookings"
        security [ bearer: [] ]
        consumes "application/json"
        parameter name: :Authorization, in: :header, schema: { type: :string }
        parameter name: :body, in: :body, schema: { type: :object, properties: { reason: { type: :string } } }
        let(:body) { { reason: "Fixed it myself" } }
        response "200", "cancelled" do
          booking_response("customer_booking")
          run_test!
        end
      end
    end

    path "/api/v1/customer/bookings/{id}/review" do
      parameter name: :id, in: :path, schema: { type: :string }
      post "Rate the worker (once, after completion)" do
        tags "Customer bookings"
        security [ bearer: [] ]
        consumes "application/json"
        parameter name: :Authorization, in: :header, schema: { type: :string }
        parameter name: :body, in: :body, schema: { type: :object, required: %w[rating], properties: { rating: { type: :integer, minimum: 1, maximum: 5 }, body: { type: :string } } }
        let(:body) { { rating: 5, body: "Great" } }
        before { act!(booking, :schedule, params: { scheduled_at: soon }) && act!(booking, :start) && act!(booking, :complete) }
        response "201", "reviewed" do
          booking_response("customer_booking")
          run_test!
        end
      end
    end

    path "/api/v1/customer/bookings/{id}/disputes" do
      parameter name: :id, in: :path, schema: { type: :string }
      post "Report a problem with finished work (within 7 days)" do
        tags "Customer bookings"
        security [ bearer: [] ]
        consumes "application/json"
        parameter name: :Authorization, in: :header, schema: { type: :string }
        parameter name: :body, in: :body, schema: { type: :object, required: %w[category description],
                                                    properties: { category: { type: :string, enum: Dispute::CATEGORIES }, description: { type: :string } } }
        let(:body) { { category: "quality", description: "Still leaking" } }
        before { act!(booking, :schedule, params: { scheduled_at: soon }) && act!(booking, :start) && act!(booking, :complete) }
        response "201", "opened" do
          booking_response("customer_booking")
          run_test!
        end
      end
    end

    path "/api/v1/customer/bookings/{id}/messages" do
      parameter name: :id, in: :path, schema: { type: :string }
      post "Send a chat message" do
        tags "Booking chat"
        security [ bearer: [] ]
        consumes "application/json"
        parameter name: :Authorization, in: :header, schema: { type: :string }
        parameter name: :body, in: :body, schema: { type: :object, required: %w[body], properties: { body: { type: :string } } }
        let(:body) { { body: "Gate code 1234" } }
        response "201", "sent" do
          schema type: :object, properties: { data: { "$ref" => "#/components/schemas/message" } }
          run_test!
        end
      end
    end
  end

  context "as support" do
    let(:Authorization) { staff_headers_for(create(:user, :support), role: "support")["Authorization"] }

    path "/api/v1/admin/bookings" do
      get "Bookings (filter[attention]=true: unscheduled, late, waiting on approval, disputed)" do
        tags "Admin bookings"
        security [ bearer: [] ]
        parameter name: :Authorization, in: :header, schema: { type: :string }
        parameter name: "filter[status]", in: :query, required: false, schema: { "$ref" => "#/components/schemas/booking_status" }
        parameter name: "filter[attention]", in: :query, required: false, schema: { type: :string, enum: %w[true] }
        response "200", "ok" do
          before { booking }
          schema type: :object, properties: { data: { type: :array, items: { "$ref" => "#/components/schemas/admin_booking_summary" } } }
          run_test!
        end
      end
    end

    path "/api/v1/admin/bookings/{id}" do
      parameter name: :id, in: :path, schema: { type: :string }
      get "One booking with history, approvals, chat and dispute" do
        tags "Admin bookings"
        security [ bearer: [] ]
        parameter name: :Authorization, in: :header, schema: { type: :string }
        response "200", "ok" do
          booking_response("admin_booking")
          run_test!
        end
      end
    end

    path "/api/v1/admin/bookings/{id}/cancel" do
      parameter name: :id, in: :path, schema: { type: :string }
      post "Cancel a booking (reason required, audited)" do
        tags "Admin bookings"
        security [ bearer: [] ]
        consumes "application/json"
        parameter name: :Authorization, in: :header, schema: { type: :string }
        parameter name: :body, in: :body, schema: { type: :object, required: %w[reason], properties: { reason: { type: :string } } }
        let(:body) { { reason: "Worker unreachable" } }
        response "200", "cancelled" do
          booking_response("admin_booking")
          run_test!
        end
      end
    end

    path "/api/v1/admin/disputes" do
      get "Disputes (open: oldest first)" do
        tags "Admin bookings"
        security [ bearer: [] ]
        parameter name: :Authorization, in: :header, schema: { type: :string }
        parameter name: "filter[status]", in: :query, required: false, schema: { type: :string, enum: %w[open resolved] }
        response "200", "ok" do
          schema type: :object, properties: { data: { type: :array, items: { "$ref" => "#/components/schemas/admin_dispute" } } }
          run_test!
        end
      end
    end

    path "/api/v1/admin/disputes/{id}/resolve" do
      parameter name: :id, in: :path, schema: { type: :string }
      post "Resolve a dispute (resolution required, audited)" do
        tags "Admin bookings"
        security [ bearer: [] ]
        consumes "application/json"
        parameter name: :Authorization, in: :header, schema: { type: :string }
        parameter name: :body, in: :body, schema: { type: :object, required: %w[resolution], properties: { resolution: { type: :string } } }
        let(:id) do
          act!(booking, :schedule, params: { scheduled_at: soon }) && act!(booking, :start) && act!(booking, :complete)
          Disputes::Open.call(booking: booking.reload, customer: booking.customer, category: "quality", description: "x").public_id
        end
        let(:body) { { resolution: "Refixed" } }
        response "200", "resolved" do
          schema type: :object, properties: { data: { "$ref" => "#/components/schemas/admin_dispute" } }
          run_test!
        end
      end
    end
  end
end
