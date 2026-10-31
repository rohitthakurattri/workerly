require "swagger_helper"

# Documents the Phase 4 endpoints (happy path + main error). Behaviour is covered in depth elsewhere.
RSpec.describe "Matching API", type: :request do
  let!(:mohali) { create(:mohali) }
  let!(:plumber) { create(:plumber) }
  let(:worker) { create(:worker_profile, :matchable) }
  let(:lead_request) { create(:service_request, :open).tap { |r| worker && Matching::InviteWorkers.call(r) } }

  context "as a worker" do
    let(:Authorization) { auth_headers_for(worker.user, role: "worker")["Authorization"] }

    path "/api/v1/worker/leads" do
      get "Live leads: requests this worker was invited to (newest first)" do
        tags "Worker leads"
        security [ bearer: [] ]
        parameter name: :Authorization, in: :header, schema: { type: :string }
        parameter name: :cursor, in: :query, required: false, schema: { type: :string }
        response "200", "ok" do
          before { lead_request }
          schema type: :object, properties: { data: { type: :array, items: { "$ref" => "#/components/schemas/lead" } },
                                              meta: { "$ref" => "#/components/schemas/page_meta" } }
          run_test! { expect(json["data"].size).to eq(1) }
        end
        response "403", "not approved, suspended or not a worker" do
          let(:Authorization) { auth_headers_for(create(:worker_profile).user, role: "worker")["Authorization"] }
          schema "$ref" => "#/components/schemas/error"
          run_test! { expect(error_code).to eq("worker_not_verified") }
        end
      end
    end

    path "/api/v1/worker/leads/{id}" do
      parameter name: :id, in: :path, schema: { type: :string }, description: "The request's id"
      get "One lead (marks it viewed)" do
        tags "Worker leads"
        security [ bearer: [] ]
        parameter name: :Authorization, in: :header, schema: { type: :string }
        response "200", "ok" do
          let(:id) { lead_request.public_id }
          schema type: :object, properties: { data: { "$ref" => "#/components/schemas/lead" } }
          run_test!
        end
        response "404", "not invited, declined or closed" do
          let(:id) { create(:service_request, :open).public_id }
          schema "$ref" => "#/components/schemas/error"
          run_test!
        end
      end
    end

    path "/api/v1/worker/leads/{id}/decline" do
      parameter name: :id, in: :path, schema: { type: :string }
      post "Not interested (hides the lead)" do
        tags "Worker leads"
        security [ bearer: [] ]
        consumes "application/json"
        parameter name: :Authorization, in: :header, schema: { type: :string }
        parameter name: :body, in: :body, schema: { type: :object, properties: { reason: { type: :string } } }
        response "204", "declined" do
          let(:id) { lead_request.public_id }
          let(:body) { { reason: "Too far" } }
          run_test!
        end
      end
    end

    path "/api/v1/cable_tickets" do
      post "One-time ticket for the WebSocket (wss …/cable?ticket=…, valid 60 s)" do
        tags "Realtime"
        security [ bearer: [] ]
        parameter name: :Authorization, in: :header, schema: { type: :string }
        response "201", "ticket" do
          schema type: :object, properties: { data: { type: :object, required: %w[ticket url expires_in],
                                                      properties: { ticket: { type: :string }, url: { type: :string }, expires_in: { type: :integer } } } }
          run_test!
        end
      end
    end

    path "/api/v1/devices/push_config" do
      get "Web push settings for the apps" do
        tags "Notifications"
        security [ bearer: [] ]
        parameter name: :Authorization, in: :header, schema: { type: :string }
        response "200", "ok" do
          schema type: :object, properties: { data: { type: :object, required: %w[enabled],
                                                      properties: { enabled: { type: :boolean }, public_key: { type: :string, nullable: true } } } }
          run_test!
        end
      end
    end

    path "/api/v1/devices" do
      post "Save this browser's push subscription for the active app" do
        tags "Notifications"
        security [ bearer: [] ]
        consumes "application/json"
        parameter name: :Authorization, in: :header, schema: { type: :string }
        parameter name: :body, in: :body, schema: { type: :object, required: %w[endpoint keys], properties: {
          endpoint: { type: :string }, keys: { type: :object, properties: { p256dh: { type: :string }, auth: { type: :string } } }
        } }
        response "201", "saved" do
          let(:body) { { endpoint: "https://fcm.googleapis.com/fcm/send/x", keys: { p256dh: "p", auth: "a" } } }
          schema type: :object, properties: { data: { type: :object, properties: { id: { type: :string }, app: { type: :string } } } }
          run_test!
        end
      end

      delete "Remove this browser's subscription (logout, alerts off)" do
        tags "Notifications"
        security [ bearer: [] ]
        consumes "application/json"
        parameter name: :Authorization, in: :header, schema: { type: :string }
        parameter name: :body, in: :body, schema: { type: :object, required: %w[endpoint], properties: { endpoint: { type: :string } } }
        response "204", "removed" do
          let(:body) { { endpoint: "https://fcm.googleapis.com/fcm/send/x" } }
          run_test!
        end
      end
    end

    path "/api/v1/notifications" do
      get "In-app notifications (newest first; meta.unread)" do
        tags "Notifications"
        security [ bearer: [] ]
        parameter name: :Authorization, in: :header, schema: { type: :string }
        response "200", "ok" do
          before { worker.user.notifications.create!(kind: "lead.new", title: "New job: Plumber") }
          schema type: :object, properties: { data: { type: :array, items: { "$ref" => "#/components/schemas/notification" } },
                                              meta: { type: :object, properties: { next_cursor: { type: :string, nullable: true }, unread: { type: :integer } } } }
          run_test!
        end
      end
    end
  end

  context "as support staff" do
    let(:Authorization) { staff_headers_for(create(:user, :support), role: "support")["Authorization"] }

    path "/api/v1/admin/service_requests" do
      get "Submitted requests; attention = open with nobody invited or no quotes after 30 min" do
        tags "Admin requests"
        security [ bearer: [] ]
        parameter name: :Authorization, in: :header, schema: { type: :string }
        parameter name: "filter[status]", in: :query, required: false, schema: { type: :string }
        parameter name: "filter[attention]", in: :query, required: false, schema: { type: :string, enum: %w[true] }
        response "200", "ok" do
          before { lead_request }
          schema type: :object, properties: { data: { type: :array, items: { "$ref" => "#/components/schemas/admin_service_request_summary" } },
                                              meta: { type: :object, properties: { next_cursor: { type: :string, nullable: true }, attention_count: { type: :integer } } } }
          run_test!
        end
      end
    end

    path "/api/v1/admin/service_requests/{id}" do
      parameter name: :id, in: :path, schema: { type: :string }
      get "One request with its invitations (rank, score, distance, notified, viewed, declined)" do
        tags "Admin requests"
        security [ bearer: [] ]
        parameter name: :Authorization, in: :header, schema: { type: :string }
        response "200", "ok" do
          let(:id) { lead_request.public_id }
          schema type: :object, properties: { data: { "$ref" => "#/components/schemas/admin_service_request_detail" } }
          run_test!
        end
      end
    end
  end
end
