require "swagger_helper"

# Documents the Phase 8 endpoints. Behaviour: spec/requests/api/v1/customer/voice_notes_spec.rb,
# spec/services/ai/triage_quality_spec.rb.
RSpec.describe "Voice notes and AI quality API docs", type: :request do
  let!(:mohali) { create(:mohali) }

  path "/api/v1/customer/service_requests/{id}/voice_note" do
    parameter name: :id, in: :path, schema: { type: :string }
    post "Add or replace the draft's voice note (≤ 3 MB, ≤ 2 min); transcribed in the background" do
      tags "Customer requests"
      security [ bearer: [] ]
      consumes "multipart/form-data"
      parameter name: :Authorization, in: :header, schema: { type: :string }
      parameter name: :file, in: :formData, schema: { type: :string, format: :binary }
      parameter name: :duration_ms, in: :formData, required: false, schema: { type: :integer }
      let(:user) { create(:user) }
      let(:Authorization) { auth_headers_for(user)["Authorization"] }
      let(:id) { create(:service_request, customer: user).public_id }
      let(:duration_ms) { 5000 }
      response "201", "stored; poll the request until voice_note.transcript_status is not pending" do
        let(:file) { fixture("voice.webm", "audio/webm") }
        schema type: :object, properties: { data: { "$ref" => "#/components/schemas/voice_note" } }
        run_test!
      end
      response "422", "not a recording (checked from the bytes) or too big" do
        let(:file) { fixture("id.jpg", "audio/webm") }
        schema "$ref" => "#/components/schemas/error"
        run_test!
      end
    end
  end

  path "/api/v1/admin/ai/quality" do
    get "Triage accuracy on real traffic: suggestion vs the category submitted (admin)" do
      tags "Admin AI"
      security [ bearer: [] ]
      parameter name: :Authorization, in: :header, schema: { type: :string }
      parameter name: :from, in: :query, required: false, schema: { type: :string }
      parameter name: :to, in: :query, required: false, schema: { type: :string }
      let(:Authorization) { staff_headers_for(create(:user, :admin), role: "admin")["Authorization"] }
      response "200", "report" do
        schema type: :object, properties: { data: { "$ref" => "#/components/schemas/ai_quality" } }
        run_test!
      end
    end
  end
end
